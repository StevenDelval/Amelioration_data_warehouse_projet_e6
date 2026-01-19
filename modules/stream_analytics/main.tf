# ============================================
# STREAM ANALYTICS JOB
# ============================================
resource "azurerm_stream_analytics_job" "asa_job" {
  name                                     = "asa-shopnow"
  resource_group_name                      = var.resource_group_name
  location                                 = var.location
  compatibility_level                      = "1.2"
  data_locale                              = "en-US"
  events_late_arrival_max_delay_in_seconds = 60
  events_out_of_order_max_delay_in_seconds = 50
  events_out_of_order_policy               = "Adjust"
  output_error_policy                      = "Drop"
  streaming_units                          = 1

  transformation_query = <<QUERY
  -- =========================
  -- ORDERS -> fact_order + fact_order_items
  -- =========================
    SELECT
      o.order_id,
      o.customer_sk,
      o.total_amount,
      CAST(o.timestamp AS datetime) AS order_date
    INTO [OutputFactOrder]
    FROM [InputOrders] o;

    SELECT
        o.order_id,
        i.ArrayValue.seller_product_sk,
        i.ArrayValue.quantity
    INTO [OutputFactOrderItems]
    FROM [InputOrders] o
    CROSS APPLY GetArrayElements(o.items) AS i;

    -- =========================
    -- CLICKSTREAM -> fact_clickstream
    -- =========================
    SELECT
        event_id,
        session_id,
        user_id,
        url,
        action AS event_type,
        CAST(timestamp AS datetime) AS event_timestamp
    INTO [OutputFactClickstream]
    FROM [InputClickstream];

    -- =========================
    -- STOCK -> fact_seller_product_stock
    -- =========================
    SELECT
        seller_product_sk,
        stock ,
        source,
        CAST(event_timestamp AS datetime) AS event_timestamp
    INTO [OutputFactStock]
    FROM [InputStock];
  QUERY
}

# ============================================
# INPUTS (EVENT HUB)
# ============================================
resource "azurerm_stream_analytics_stream_input_eventhub" "input_orders" {
  name                         = "InputOrders"
  stream_analytics_job_name    = azurerm_stream_analytics_job.asa_job.name
  resource_group_name          = var.resource_group_name
  eventhub_consumer_group_name = "$Default"
  eventhub_name                = "orders"
  servicebus_namespace         = var.eventhub_namespace_name
  shared_access_policy_name    = "listen-policy"
  shared_access_policy_key     = var.eventhub_listen_key

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}

resource "azurerm_stream_analytics_stream_input_eventhub" "input_clickstream" {
  name                         = "InputClickstream"
  stream_analytics_job_name    = azurerm_stream_analytics_job.asa_job.name
  resource_group_name          = var.resource_group_name
  eventhub_consumer_group_name = "$Default"
  eventhub_name                = "clickstream"
  servicebus_namespace         = var.eventhub_namespace_name
  shared_access_policy_name    = "listen-policy"
  shared_access_policy_key     = var.eventhub_listen_key

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}

resource "azurerm_stream_analytics_stream_input_eventhub" "input_stock" {
  name                         = "InputStock"
  stream_analytics_job_name    = azurerm_stream_analytics_job.asa_job.name
  resource_group_name          = var.resource_group_name
  eventhub_consumer_group_name = "$Default"
  eventhub_name                = "stock"
  servicebus_namespace         = var.eventhub_namespace_name
  shared_access_policy_name    = "listen-policy"
  shared_access_policy_key     = var.eventhub_listen_key

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}

# ============================================
# OUTPUTS (SQL SERVER)
# ============================================
resource "azurerm_stream_analytics_output_mssql" "output_fact_order" {
  name                      = "OutputFactOrder"
  stream_analytics_job_name = azurerm_stream_analytics_job.asa_job.name
  resource_group_name       = var.resource_group_name
  server                    = var.sql_server_fqdn
  user                      = var.sql_admin_login
  password                  = var.sql_admin_password
  database                  = var.sql_database_name
  table                     = "fact_order"
}

resource "azurerm_stream_analytics_output_mssql" "output_fact_order_items" {
  name                      = "OutputFactOrderItems"
  stream_analytics_job_name = azurerm_stream_analytics_job.asa_job.name
  resource_group_name       = var.resource_group_name
  server                    = var.sql_server_fqdn
  user                      = var.sql_admin_login
  password                  = var.sql_admin_password
  database                  = var.sql_database_name
  table                     = "fact_order_items"
}

resource "azurerm_stream_analytics_output_mssql" "output_fact_clickstream" {
  name                      = "OutputFactClickstream"
  stream_analytics_job_name = azurerm_stream_analytics_job.asa_job.name
  resource_group_name       = var.resource_group_name
  server                    = var.sql_server_fqdn
  user                      = var.sql_admin_login
  password                  = var.sql_admin_password
  database                  = var.sql_database_name
  table                     = "fact_clickstream"
}

resource "azurerm_stream_analytics_output_mssql" "output_fact_stock" {
  name                      = "OutputFactStock"
  stream_analytics_job_name = azurerm_stream_analytics_job.asa_job.name
  resource_group_name       = var.resource_group_name
  server                    = var.sql_server_fqdn
  user                      = var.sql_admin_login
  password                  = var.sql_admin_password
  database                  = var.sql_database_name
  table                     = "fact_seller_product_stock"
}


# Terraform crée et configure le job Stream Analytics, mais Azure ne démarre
# jamais automatiquement un job ASA après son déploiement. Sans un démarrage
# explicite, le job reste à l'état "Stopped" et ne consomme aucun événement.
resource "null_resource" "start_job" {
  triggers = {
    job_id = azurerm_stream_analytics_job.asa_job.id
  }

  depends_on = [
    azurerm_stream_analytics_job.asa_job,
    azurerm_stream_analytics_stream_input_eventhub.input_orders,
    azurerm_stream_analytics_stream_input_eventhub.input_clickstream,
    azurerm_stream_analytics_stream_input_eventhub.input_stock,
    azurerm_stream_analytics_output_mssql.output_fact_order,
    azurerm_stream_analytics_output_mssql.output_fact_order_items,
    azurerm_stream_analytics_output_mssql.output_fact_clickstream,
    azurerm_stream_analytics_output_mssql.output_fact_stock,
  ]

  provisioner "local-exec" {
    command = "az stream-analytics job start --resource-group ${var.resource_group_name} --name ${azurerm_stream_analytics_job.asa_job.name} --output-start-mode JobStartTime"
  }
}
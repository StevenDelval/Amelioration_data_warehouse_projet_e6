resource "azurerm_resource_group" "rg" {
  name     = "rg-e6-${var.username}"
  location = var.location
}

// Event Hubs
module "module_event_hubs" {
  source                  = "./modules/event_hubs"
  depends_on              = [azurerm_resource_group.rg]
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  eventhub_namespace_name = "eh-${var.username}"
  eventhubs               = var.eventhubs
}

// DB
module "sql_database" {
  source              = "./modules/sql_database"
  depends_on          = [module.module_event_hubs]
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sql_admin_login     = var.sql_admin_login
  sql_admin_password  = var.sql_admin_password
  schema_file_path    = "${path.root}/../database/dwh_schema.sql"
}

// Stream
module "stream_analytics" {
  source                  = "./modules/stream_analytics"
  depends_on              = [module.module_event_hubs, module.sql_database]
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  eventhub_namespace_name = "eh-${var.username}"
  eventhub_listen_key     = module.module_event_hubs.listen_connection_string
  sql_server_fqdn         = module.sql_database.server_fqdn
  sql_database_name       = module.sql_database.database_name
  sql_admin_login         = var.sql_admin_login
  sql_admin_password      = var.sql_admin_password
}

# module "make_docker_image" {
#   source     = "./modules/make_docker_image"
#   container_registry_name = "acre6sdelval"
#   resource_group_name = azurerm_resource_group.rg.name
#   location =  var.location
#   image_name = "event_hub_producers"
#   path_image = "${path.root}/_events_producers"
# }

# // Event producers
# module "container_producers" {
#   source     = "./modules/container_producers"
#   depends_on = [module.module_event_hubs, module.stream_analytics, module.make_docker_image]

#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location

#   container_image   = "${module.make_docker_image.login_server}/event_hub_producers"
#   connection_string = module.module_event_hubs.send_connection_string

#   acr_login_server = module.make_docker_image.login_server
#   acr_username = module.make_docker_image.admin_username
#   acr_password = module.make_docker_image.admin_password
#   sql_admin_password = var.sql_admin_password
#   sql_admin_user = var.sql_admin_login
#   sql_db = module.sql_database.database_name
#   sql_server = module.sql_database.server_fqdn
# }


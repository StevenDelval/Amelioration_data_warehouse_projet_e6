resource "azurerm_container_registry" "acr" {
  name                = var.container_registry_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "null_resource" "docker_push" {
  provisioner "local-exec" {
    command = <<EOT
    BUILD_PATH=${var.path_image}
    ACR_NAME=${azurerm_container_registry.acr.name}
    RESOURCE_GROUP=${var.resource_group_name}
    ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "loginServer" --output tsv)
    ACR_IMAGE_NAME=${var.image_name}

    az acr login --name $ACR_NAME
    docker build $BUILD_PATH -t $ACR_LOGIN_SERVER/$ACR_IMAGE_NAME
    docker push $ACR_LOGIN_SERVER/$ACR_IMAGE_NAME

    EOT
  }
  depends_on = [azurerm_container_registry.acr]
}
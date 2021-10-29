resource "azurerm_resource_group" "main" {
  name     = var.base-name
  location = var.location
}

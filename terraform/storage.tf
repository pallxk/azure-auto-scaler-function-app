resource "azurerm_storage_account" "main" {
  name                = local.basename
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  account_tier             = "Standard"
  account_replication_type = "GRS"

  allow_blob_public_access = true
}

resource "azurerm_storage_container" "functionapp" {
  name                 = "functionapp"
  storage_account_name = azurerm_storage_account.main.name

  container_access_type = "blob"
}

output "storage_container_id" {
  value = azurerm_storage_container.functionapp.id
}

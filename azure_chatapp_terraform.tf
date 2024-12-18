provider "azurerm" {
  features {}
}

# Create a Storage Account for static content
resource "azurerm_storage_account" "static_content" {
  name                     = "mystaticcontent"
  resource_group_name      = "myResourceGroup"
  location                 = "East US"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  static_website {
    index_document = "index.html"
    error_404_document = "404.html"
  }
}

# Create a Cosmos DB for storing messages
resource "azurerm_cosmosdb_account" "messages" {
  name                = "mycosmosdb"
  location            = "East US"
  resource_group_name = "myResourceGroup"
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }
}

resource "azurerm_cosmosdb_sql_database" "messages_db" {
  name                = "MessagesDB"
  resource_group_name = "myResourceGroup"
  account_name        = azurerm_cosmosdb_account.messages.name
}

resource "azurerm_cosmosdb_sql_container" "messages_container" {
  name                = "MessagesContainer"
  resource_group_name = "myResourceGroup"
  account_name        = azurerm_cosmosdb_account.messages.name
  database_name       = azurerm_cosmosdb_sql_database.messages_db.name
  partition_key_path  = "/MessageID"

  throughput = 400
}

# Create an Azure Function App for WebSocket handling
resource "azurerm_function_app" "websocket_handler" {
  name                       = "websockethandler"
  resource_group_name        = "myResourceGroup"
  location                   = "East US"
  storage_account_name       = azurerm_storage_account.static_content.name
  storage_account_access_key = azurerm_storage_account.static_content.primary_access_key
  app_service_plan_id        = azurerm_app_service_plan.plan.id

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "node"
  }
}

# Create an App Service Plan
resource "azurerm_app_service_plan" "plan" {
  name                = "myAppServicePlan"
  resource_group_name = "myResourceGroup"
  location            = "East US"
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

# API Management for Routing
resource "azurerm_api_management" "api_gateway" {
  name                = "myApiGateway"
  location            = "East US"
  resource_group_name = "myResourceGroup"
  publisher_name      = "myPublisher"
  publisher_email     = "myemail@example.com"
}

resource "azurerm_api_management_api" "websocket_api" {
  name                = "WebSocketAPI"
  resource_group_name = "myResourceGroup"
  api_management_name = azurerm_api_management.api_gateway.name
  revision            = "1"
  protocols           = ["https"]
  display_name        = "WebSocket API"
  path                = "websocket"

  import {
    content_format = "swagger-json"
    content_value  = file("./swagger.json")
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.project_name}-rg-${var.environment}"
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name = "wpiacdemoacr${var.environment}" 
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  sku                      = "Standard"
  admin_enabled            = true  
}



# APP web

resource "azurerm_service_plan" "app_plan" {
  name                = "${var.project_name}-plan-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "S1"
}


resource "azurerm_linux_web_app" "web" {
  name                = "${var.project_name}-web-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.app_plan.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      docker_image_name   = "custom-wordpress:${var.environment}"
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }

    linux_fx_version = null  
  }

  app_settings = {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    DOCKER_REGISTRY_SERVER_URL          = "https://${azurerm_container_registry.acr.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME     = azurerm_container_registry.acr.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD     = azurerm_container_registry.acr.admin_password

    WORDPRESS_DB_HOST     = azurerm_mysql_flexible_server.db.fqdn
    WORDPRESS_DB_NAME     = var.mysql_database_name
    WORDPRESS_DB_USER     = "${var.mysql_admin_user}@${azurerm_mysql_flexible_server.db.name}"
    WORDPRESS_DB_PASSWORD = var.mysql_admin_password
  }
}


resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project_name}-vnet-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "mysql_subnet" {
  name                 = "${var.project_name}-subnet-mysql-${var.environment}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "mysqlDelegation"
    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  depends_on = [azurerm_virtual_network.vnet]
}


resource "azurerm_mysql_flexible_server" "db" {
  name                = "${var.project_name}-mysql-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku_name = "B_Standard_B1ms"
  version = "8.0.21"

  administrator_login    = var.mysql_admin_user
  administrator_password = var.mysql_admin_password

  storage {
    size_gb = 32
  }

  private_dns_zone_id = azurerm_private_dns_zone.mysql.id
}


# Base de données initiale
resource "azurerm_mysql_flexible_database" "wordpressdb" {
  name                = var.mysql_database_name
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.db.name
  charset             = "utf8"
  collation           = "utf8_general_ci"
}

resource "azurerm_private_dns_zone" "mysql" {
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}


resource "azurerm_private_dns_zone_virtual_network_link" "mysql_link" {
  name                  = "${var.project_name}-mysql-dnslink-${var.environment}"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Intégration VNet de la Web App (pour qu'elle joigne le subnet MySQL)
resource "azurerm_app_service_virtual_network_swift_connection" "vnet_integration" {
  app_service_id = azurerm_linux_web_app.web.id
  subnet_id = azurerm_subnet.webapp_subnet.id
}

resource "azurerm_subnet" "webapp_subnet" {
  name                 = "${var.project_name}-subnet-webapp-${var.environment}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "webappDelegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  depends_on = [azurerm_virtual_network.vnet]
}

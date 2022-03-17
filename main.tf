
#we are trying to add multiple private endpoints to one container registries

terraform {

  required_version = ">= 0.12"

} 

provider "azurerm" {

  version = ">=2.20"

  features {} 

}

data "azurerm_subscription" "current" {}

data "azurerm_resource_group" "rgrp" {

  name = var.resource_group_name

}

data "azurerm_container_registry" "main" {

  name                          = "containerregistryname"

  resource_group_name           = data.azurerm_resource_group.rgrp.name

}

data "azurerm_virtual_network" "vnet01" {

  name                = var.virtual_network_name

  resource_group_name = data.azurerm_resource_group.rgrp.name

}

#For existing subnets who has "enforce_private_link_endpoint_network_policies" enabled we can create a container registry with no problem
data "azurerm_subnet" "subnets" {

  for_each             = var.subnets

  name                 = each.value.name

  resource_group_name                            = data.azurerm_resource_group.rgrp.name
  virtual_network_name                           = data.azurerm_virtual_network.vnet01.name

}

#I need to enable enforce_private_link_endpoint_network_policies for existing subnets but instead of updating it  this below block trying to create new subnet can some one help regaing these issue
/* 
resource "azurerm_subnet" "updatesubnet" {
for_each             = var.subnets
  name                 = each.value.name
  resource_group_name                            = data.azurerm_resource_group.rgrp.name
  virtual_network_name                           = data.azurerm_virtual_network.vnet01.name
  address_prefixes                               = each.value.addressprefixes
  enforce_private_link_endpoint_network_policies = true
}

*/

resource "azurerm_private_endpoint" "pep1" {

  for_each             =var.subnets

  name                = each.value.privateendpoint

  location            = data.azurerm_resource_group.rgrp.location

  resource_group_name = data.azurerm_resource_group.rgrp.name

  subnet_id           = data.azurerm_subnet.subnets[each.key].id 

  private_dns_zone_group {
    name                 = "npdcontainerregistry-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.dnszone1[each.key].id]
    
  }

  private_service_connection {

    name                           = each.value.serviceconnectname

    is_manual_connection           = false

    private_connection_resource_id = data.azurerm_container_registry.main.id

    subresource_names              = ["registry"]

   }

 }


resource "azurerm_private_dns_zone" "dnszone1" {
  for_each             =var.subnets
  name                = each.value.dnsname
  resource_group_name = data.azurerm_resource_group.rgrp.name
  
}

resource "azurerm_private_dns_zone_virtual_network_link" "vent-link1" {
  for_each              = var.subnets
  name                  = each.value.vnetlinkname
  resource_group_name   = data.azurerm_resource_group.rgrp.name
  private_dns_zone_name = azurerm_private_dns_zone.dnszone1[each.key].name
  virtual_network_id    = data.azurerm_virtual_network.vnet01.id
}

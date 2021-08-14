# provider "azuredevops" {
#   version = ">= 0.0.1"
#   source = "microsoft/azuredevops"
#   # Remember to specify the org service url and personal access token details below
# #   org_service_url = "xxxxxxxxxxxxxxxxxxxx"
# #   personal_access_token = "xxxxxxxxxxxxxxxxxxxx"
# }


terraform {
  required_providers {
    azuredevops = {
      source = "microsoft/azuredevops"
      version = ">=0.1.0"
    }
  }
}

resource "azuredevops_serviceendpoint_github" "github" {
  project_id            = azuredevops_project.droneapp.id
  service_endpoint_name = "GithHub"
  auth_oauth {
    oauth_configuration_id = "00000000-0000-0000-0000-000000000000"
  }
}

resource "azuredevops_project" "droneapp" {
  name       = var.project_name
  description        = var.description
  visibility         = var.visibility
  version_control    = var.version_control
  work_item_template = var.work_item_template
  # Enable or desiable the DevOps fetures below (enabled / disabled)

  features = {
      "boards" = "disabled"
      "repositories" = "disabled"
      "pipelines" = "enabled"
      "testplans" = "disabled"
      "artifacts" = "enabled"
  }
}

resource "azuredevops_build_definition" "ci" {
  project_id      = azuredevops_project.droneapp.id
  #agent_pool_name = "Hosted Ubuntu 2004"
  name            = "CI"
  path            = "\\"
  variable_groups = [azuredevops_variable_group.common.id]
  repository {
    repo_type             = "GitHub"
    repo_id               = var.MYREPO
    branch_name           = "master"
    yml_path              = "azure-pipelines.yml"
    service_connection_id = azuredevops_serviceendpoint_github.github.id
  }
}

// Configuration of AzureRm service end point
# resource "azuredevops_serviceendpoint_azurerm" "arm" {
#   project_id            = azuredevops_project.droneapp.id
#   service_endpoint_name = "AzureRM"
#   credentials {
#     serviceprincipalid  = "00000000-0000-0000-0000-000000000000"
#     serviceprincipalkey = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
#   }
#   azurerm_spn_tenantid      = "00000000-0000-0000-0000-000000000000"
#   azurerm_subscription_id   = "00000000-0000-0000-0000-000000000000"
#   azurerm_subscription_name = "Microsoft Azure DEMO"
# }

resource "azuredevops_variable_group" "common" {
  project_id   = azuredevops_project.droneapp.id
  name         = "Common"
  description  = "Vars shared by all pipelines"
  allow_access = true

  variable {
    name      = "secret_token"
    value     = "p@$$w)rd"
    is_secret = true
  }

  variable {
    name  = "location"
    value = "Redmond"
  }

  variable {
    name = "without_value"
  }
}
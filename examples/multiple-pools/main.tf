terraform {
  required_providers {
    acloud = {
      source  = "avisi-cloud/acloud"
      version = ">= 0.12.0"
    }
  }
}

variable "acloud_token" {
  description = "Avisi Cloud Personal Access Token. Create one under API Access in the Console."
  type        = string
  sensitive   = true
}

variable "acloud_api" {
  description = "Avisi Cloud API base URL. Leave null to use the public API at https://api.avisi.cloud."
  type        = string
  default     = null
}

provider "acloud" {
  token      = var.acloud_token
  acloud_api = var.acloud_api
}

variable "organisation_slug" {
  description = "Slug of the Avisi Cloud organisation that owns the cluster."
  type        = string
  nullable    = false
}

variable "environment_slug" {
  description = "Slug of the AME environment the cluster lives in."
  type        = string
  nullable    = false
}

variable "cluster_slug" {
  description = "Slug of the existing cluster to attach the node pool to."
  type        = string
  nullable    = false
}

variable "cloud_provider" {
  description = "Cloud provider slug the cluster runs on."
  type        = string
  default     = "aws"
}

variable "region" {
  description = "Region the cluster is deployed in."
  type        = string
  default     = "eu-west-1"
}

variable "node_pools" {
  description = "Node pools to create, keyed by pool name."
  type = map(object({
    node_size                       = string
    node_count                      = optional(number, 1)
    enable_multi_availability_zones = optional(bool, true)
    availability_zone               = optional(string, "")
    labels                          = optional(map(string), {})
  }))
  default = {
    system = {
      node_size = "t3.medium"
      labels    = { "role" = "system" }
    }
    apps = {
      node_size  = "t3.large"
      node_count = 2
      labels     = { "role" = "apps" }
    }
    data = {
      node_size                       = "t3.large"
      node_count                      = 3
      enable_multi_availability_zones = false
      availability_zone               = "eu-west-1a"
      labels                          = { "role" = "data" }
    }
  }
}

# Calling the module once per entry is how you build a differentiated cluster
# from this module directly - it is exactly what avisi-cloud/cluster/acloud
# does internally.
module "node_pool" {
  source   = "../../"
  for_each = var.node_pools

  organisation_slug = var.organisation_slug
  environment_slug  = var.environment_slug
  cluster_slug      = var.cluster_slug
  cloud_provider    = var.cloud_provider
  region            = var.region

  name                            = each.key
  node_size                       = each.value.node_size
  node_count                      = each.value.node_count
  enable_multi_availability_zones = each.value.enable_multi_availability_zones
  availability_zone               = each.value.availability_zone
  labels                          = each.value.labels
}

output "node_pools" {
  description = "Created node pools, keyed by pool name and then by availability zone."
  value       = { for name, mod in module.node_pool : name => mod.node_pool }
}

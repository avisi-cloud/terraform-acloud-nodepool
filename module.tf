terraform {
  required_providers {
    acloud = {
      version = ">= 0.3.0"
      source  = "avisi-cloud/acloud"
    }
  }
}

data "acloud_cloud_provider_availability_zones" "zones" {
  organisation   = var.organisation_slug
  cloud_provider = var.cloud_provider
  region         = var.region
}

variable "availability_zone" {
  default     = ""
  description = "Default availability zone to use when the node pool is not deployed across all AZs"
  type        = string
}

resource "acloud_nodepool" "pool" {
  organisation = var.organisation_slug
  environment  = var.environment_slug
  cluster      = var.cluster_slug
  name         = var.name
  node_count   = var.node_count
  node_size    = var.node_size
  min_size     = var.node_count
  max_size     = var.node_count

  labels                = var.labels
  annotations           = var.annotations
  node_auto_replacement = var.enable_auto_healing

  for_each          = var.enable_multi_availability_zones ? toset(data.acloud_cloud_provider_availability_zones.zones.availability_zones) : [var.availability_zone]
  availability_zone = each.key
}

output "node_pool" {
  value = acloud_nodepool.pool
}

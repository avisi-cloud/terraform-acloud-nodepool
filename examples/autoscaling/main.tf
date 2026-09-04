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

variable "availability_zone" {
  description = "Availability zone for the batch pool. Must be a zone within `region`."
  type        = string
  default     = "eu-west-1a"
}

# A dedicated batch pool: autoscaled, tainted so only tolerating workloads land
# on it, and patched before its nodes join.
module "batch" {
  source = "../../"

  organisation_slug = var.organisation_slug
  environment_slug  = var.environment_slug
  cluster_slug      = var.cluster_slug
  cloud_provider    = var.cloud_provider
  region            = var.region

  # Single zone so the autoscaler bounds below are the whole pool, not per zone.
  enable_multi_availability_zones = false
  availability_zone               = var.availability_zone

  name      = "batch"
  node_size = "t3.large"

  # AME's cluster autoscaler sizes the pool on utilisation.
  enable_auto_scaling = true
  min_size            = 0
  max_size            = 10
  node_count          = 1

  # Only pods that tolerate this taint are scheduled here.
  taints = [
    {
      key    = "dedicated"
      value  = "batch"
      effect = "NoSchedule"
    },
  ]

  # Nodes join fully patched. Recommended by AME, and it is what makes
  # autoscaling safe to combine with automatic node reboots.
  security_updates_on_join = "INSTALL_AND_REBOOT"

  # Batch work tolerates a drain, so upgrade in place rather than replacing.
  upgrade_strategy = "INPLACE"

  labels = {
    "role" = "batch"
  }
}

output "node_pool" {
  description = "Created node pools, keyed by availability zone."
  value       = module.batch.node_pool
}

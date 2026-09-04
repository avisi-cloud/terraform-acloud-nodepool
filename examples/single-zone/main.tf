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
  description = "Availability zone to place the node pool in. Must be a zone within `region`."
  type        = string
  default     = "eu-west-1a"
}

# One node pool, in one availability zone. `node_count` is the literal number
# of machines because there is no fan-out.
module "node_pool" {
  source = "../../"

  organisation_slug = var.organisation_slug
  environment_slug  = var.environment_slug
  cluster_slug      = var.cluster_slug
  cloud_provider    = var.cloud_provider
  region            = var.region

  enable_multi_availability_zones = false
  availability_zone               = var.availability_zone

  name       = "data"
  node_size  = "t3.large"
  node_count = 3

  labels = {
    "role" = "data"
  }
}

output "node_pool" {
  description = "Created node pools, keyed by availability zone."
  value       = module.node_pool.node_pool
}

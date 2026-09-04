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
  description = "Region the cluster is deployed in. Its availability zones determine the fan-out."
  type        = string
  default     = "eu-west-1"
}

# One node pool per availability zone in the region. `node_count` is per zone,
# so in a three-zone region this provisions six machines, not two.
module "node_pool" {
  source = "../../"

  organisation_slug = var.organisation_slug
  environment_slug  = var.environment_slug
  cluster_slug      = var.cluster_slug
  cloud_provider    = var.cloud_provider
  region            = var.region

  enable_multi_availability_zones = true

  name       = "apps"
  node_size  = "t3.medium"
  node_count = 2

  labels = {
    "role" = "apps"
  }
}

output "node_pool" {
  description = "Created node pools, keyed by availability zone."
  value       = module.node_pool.node_pool
}

output "availability_zones" {
  description = "The zones the pool was fanned out over."
  value       = keys(module.node_pool.node_pool)
}

terraform {
  required_providers {
    acloud = {
      version = ">= 0.3.0"
      source  = "avisi-cloud/acloud"
    }
  }
}

# The availability zones of the cluster's region. This is what the multi-zone
# fan-out below iterates over.
#
# NOTE: the lookup is unconditional, so it costs one API call per plan even
# when `enable_multi_availability_zones` is false and the result is unused.
data "acloud_cloud_provider_availability_zones" "zones" {
  organisation   = var.organisation_slug
  cloud_provider = var.cloud_provider
  region         = var.region
}

# One `acloud_nodepool` per availability zone when multi-zone is enabled,
# otherwise exactly one in `availability_zone`. Every zone's pool carries the
# same name, node size and node count - they differ only by zone, which is why
# `node_count` is a *per zone* number rather than a pool total.
#
# `min_size` and `max_size` are pinned to `node_count` and `auto_scaling` is
# never set, so pools created by this module do not autoscale.
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
  description = "The created node pools, as a map keyed by availability zone. Each value is the full `acloud_nodepool` resource, so `identity`, `name`, `node_count` and the rest are available per zone. With multi-zone disabled the map has a single entry, keyed by `availability_zone`."

  value = acloud_nodepool.pool
}

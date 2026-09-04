terraform {
  required_providers {
    acloud = {
      version = ">= 0.12.0"
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
# `min_size` and `max_size` fall back to `node_count`, which reproduces the
# fixed-size behaviour this module had before autoscaling was configurable.
resource "acloud_nodepool" "pool" {
  organisation = var.organisation_slug
  environment  = var.environment_slug
  cluster      = var.cluster_slug
  name         = var.name
  node_count   = var.node_count
  node_size    = var.node_size

  auto_scaling = var.enable_auto_scaling
  min_size     = coalesce(var.min_size, var.node_count)
  max_size     = coalesce(var.max_size, var.node_count)

  labels                = var.labels
  annotations           = var.annotations
  node_auto_replacement = var.enable_auto_healing

  upgrade_strategy         = var.upgrade_strategy
  security_updates_on_join = var.security_updates_on_join

  dynamic "taints" {
    for_each = var.taints
    content {
      key    = taints.value.key
      value  = taints.value.value
      effect = taints.value.effect
    }
  }

  for_each          = var.enable_multi_availability_zones ? toset(data.acloud_cloud_provider_availability_zones.zones.availability_zones) : [var.availability_zone]
  availability_zone = each.key
}

output "node_pool" {
  description = "The created node pools, as a map keyed by availability zone. Each value is the full `acloud_nodepool` resource, so `identity`, `name`, `node_count` and the rest are available per zone. With multi-zone disabled the map has a single entry, keyed by `availability_zone`."

  value = acloud_nodepool.pool
}

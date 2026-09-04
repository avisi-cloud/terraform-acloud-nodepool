terraform {
  # `optional()` is not used here, but data source postconditions below are, and
  # those need Terraform 1.2. `nullable` on variables needs 1.1.
  required_version = ">= 1.2.0"

  required_providers {
    acloud = {
      version = ">= 0.12.0"
      source  = "avisi-cloud/acloud"
    }
  }
}

# The availability zones of the cluster's region, which the multi-zone fan-out
# below iterates over. Only queried when multi-zone is enabled - a single-zone
# pool takes its zone from `availability_zone` and never needs the lookup.
#
# The postcondition guards a silent failure mode: AME returns an empty zone list
# for a region that has no zones registered against that exact region slug, and
# `for_each` over an empty set creates zero node pools without reporting an
# error. Failing at plan time is far easier to diagnose than an apply that
# succeeds and provisions nothing.
data "acloud_cloud_provider_availability_zones" "zones" {
  count = var.enable_multi_availability_zones ? 1 : 0

  organisation   = var.organisation_slug
  cloud_provider = var.cloud_provider
  region         = var.region

  lifecycle {
    postcondition {
      condition     = length(self.availability_zones) > 0
      error_message = "No availability zones were returned for cloud provider '${var.cloud_provider}' region '${var.region}'. Multi-zone node pools cannot be created. Check the region slug: some AME cloud providers expose multi-zone regions under a separate slug. Run `acloud cloud-providers get` to list the regions and their zones, or set enable_multi_availability_zones = false."
    }
  }
}

# One `acloud_nodepool` per availability zone when multi-zone is enabled,
# otherwise exactly one in `availability_zone`. Every zone's pool carries the
# same name, node size and node count - they differ only by zone, which is why
# `node_count` is a *per zone* number rather than a pool total.
#
# On `node_count`, `min_size` and `max_size`: the provider does not send a node
# count to the API at all. It sends `min_size` and `max_size`, and when
# `auto_scaling` is false it overwrites both with `node_count` itself. So a
# fixed-size pool is really min == max == node_count, and an autoscaled pool
# ignores `node_count` entirely. Passing node_count through the coalesce below
# reproduces the fixed-size behaviour this module had before autoscaling was
# configurable.
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

  # `upgrade_strategy` is always sent, and is never null. The provider parses
  # this attribute unconditionally on create and rejects the empty string that
  # an unset value produces, so a node pool that leaves it out fails to create.
  # See the variable for details.
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

  for_each          = var.enable_multi_availability_zones ? toset(data.acloud_cloud_provider_availability_zones.zones[0].availability_zones) : toset([var.availability_zone])
  availability_zone = each.key
}

output "node_pool" {
  description = "The created node pools, as a map keyed by availability zone. Each value is the full `acloud_nodepool` resource, so `identity`, `name`, `node_count` and the rest are available per zone. With multi-zone disabled the map has a single entry, keyed by `availability_zone`."

  value = acloud_nodepool.pool
}

output "availability_zones" {
  description = "The availability zones the pool was created in, as a sorted list. With multi-zone enabled this is every zone in the region; with it disabled it is the single `availability_zone`."

  value = sort(keys(acloud_nodepool.pool))
}

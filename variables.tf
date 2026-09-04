# ---------------------------------------------------------------------------
# Placement
#
# The cluster must already exist. This module attaches a node pool to it; it
# never creates or modifies the cluster itself.
# ---------------------------------------------------------------------------

variable "organisation_slug" {
  description = "Slug of the Avisi Cloud organisation that owns the cluster. This is the short identifier used in Console URLs and API paths, not the display name. Run `acloud config get-organisations` to list the slugs you have access to."
  type        = string
  nullable    = false
}

variable "environment_slug" {
  description = "Slug of the AME environment the cluster lives in. An environment groups clusters inside an organisation, for example `production` or `staging`."
  type        = string
  nullable    = false
}

variable "cluster_slug" {
  description = "Slug of the cluster to attach the node pool to. AME derives this from the cluster's display name; it is the identifier shown on the cluster page and used by `acloud` commands. Can only be set at creation time."
  type        = string
}

# ---------------------------------------------------------------------------
# Availability zone resolution
#
# `cloud_provider` and `region` are not written to the node pool. They exist
# only so the module can ask AME which availability zones the region has, which
# is what `enable_multi_availability_zones` fans out over.
# ---------------------------------------------------------------------------

variable "cloud_provider" {
  description = "Slug of the AME cloud provider the cluster runs on, for example `aws`, `hetzner` or `cyso-cloud-ams2`. Used together with `region` to look up the region's availability zones - it is not an attribute of the node pool itself. Run `acloud cloud-providers get` to list the slugs available to your organisation."
  type        = string
  nullable    = false
}

variable "region" {
  description = "Slug of the cloud provider region the cluster is deployed in, for example `eu-west-1`, `fsn1` or `ams2`. Used together with `cloud_provider` to look up the region's availability zones. Must match the region the cluster was created in."
  type        = string
  nullable    = false
}

variable "enable_multi_availability_zones" {
  description = "Create one node pool in every availability zone of `region` instead of a single pool. Each zone's pool is sized `node_count`, so the machine count is `node_count` multiplied by the number of zones. When false, a single pool is created in `availability_zone`."
  type        = bool
  default     = false
}

variable "availability_zone" {
  description = "Availability zone for the node pool when `enable_multi_availability_zones` is false, for example `eu-west-1a`. Ignored when multi-zone is enabled, because the pool is then created in every zone. The empty default lets AME place the pool. Can only be set at creation time."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Node pool configuration
#
# Applied identically to every node in the pool, and to every zone's pool when
# multi-zone is enabled.
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name of the node pool. AME uses it for the Kubernetes node role label on every node in the pool. With `enable_multi_availability_zones` enabled, the same name is used for each zone's pool - they differ only by availability zone."
  type        = string
  default     = "worker"
}

variable "node_size" {
  description = "Cloud provider machine type for nodes in the pool, for example `t3.medium` (AWS), `cx33` (Hetzner) or `s5.small` (Cyso Cloud AMS2). The type must be offered in `region` for the cluster's cloud account."
  type        = string
}

variable "node_count" {
  description = "Number of machines in the node pool. With `enable_multi_availability_zones` enabled this is the count *per availability zone*, so the pool provisions this many nodes in every zone of the region."
  type        = number
  default     = 1
}

variable "labels" {
  description = "Kubernetes node labels applied to every node in the pool. Use them for scheduling with `nodeSelector` or node affinity."
  type        = map(string)
  default     = {}
}

variable "annotations" {
  description = "Kubernetes node annotations applied to every node in the pool. Typically consumed by automation rather than by the scheduler."
  type        = map(string)
  default     = {}
}

variable "enable_auto_healing" {
  description = "Let AME automatically replace nodes in this pool that it detects as unhealthy. Maps to `node_auto_replacement` on the underlying `acloud_nodepool` resource."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Scaling
#
# Leave `enable_auto_scaling` off and the pool holds exactly `node_count`
# machines. Turn it on and AME's cluster autoscaler moves the pool between
# `min_size` and `max_size` based on utilisation.
# ---------------------------------------------------------------------------

variable "enable_auto_scaling" {
  description = "Let the AME cluster autoscaler size this node pool based on utilisation, between `min_size` and `max_size`. When false, the pool stays at `node_count` machines."
  type        = bool
  default     = false
}

variable "min_size" {
  description = "Minimum number of machines the autoscaler may scale the pool down to. Only used when `enable_auto_scaling` is true. Defaults to `node_count` when null."
  type        = number
  default     = null
}

variable "max_size" {
  description = "Maximum number of machines the autoscaler may scale the pool up to. Only used when `enable_auto_scaling` is true. Defaults to `node_count` when null."
  type        = number
  default     = null
}

# ---------------------------------------------------------------------------
# Lifecycle and scheduling
# ---------------------------------------------------------------------------

variable "upgrade_strategy" {
  description = "How nodes in this pool are upgraded. `REPLACE` always provisions replacement nodes; `REPLACE_MINOR_INPLACE_PATCH` replaces on minor upgrades and patches in place after draining; `REPLACE_MINOR_INPLACE_PATCH_WITHOUT_DRAIN` does the same without draining; `INPLACE` always upgrades in place after draining; `INPLACE_WITHOUT_DRAIN` upgrades in place without draining. Leave null to use the AME default, `REPLACE_MINOR_INPLACE_PATCH_WITHOUT_DRAIN`."
  type        = string
  default     = null

  validation {
    condition = var.upgrade_strategy == null || contains([
      "REPLACE",
      "REPLACE_MINOR_INPLACE_PATCH",
      "REPLACE_MINOR_INPLACE_PATCH_WITHOUT_DRAIN",
      "INPLACE",
      "INPLACE_WITHOUT_DRAIN",
    ], coalesce(var.upgrade_strategy, "REPLACE"))
    error_message = "upgrade_strategy must be one of REPLACE, REPLACE_MINOR_INPLACE_PATCH, REPLACE_MINOR_INPLACE_PATCH_WITHOUT_DRAIN, INPLACE, INPLACE_WITHOUT_DRAIN, or null."
  }
}

variable "security_updates_on_join" {
  description = "Whether OS security updates are installed while a node is provisioned, before it joins the cluster. `OFF` joins with the base image packages; `INSTALL` installs updates first; `INSTALL_AND_REBOOT` also reboots when the updates require it. AME recommends `INSTALL_AND_REBOOT`, which avoids a fresh node being drained for a reboot shortly after joining. Applies only to a node's first join, never to existing nodes, and it makes bring-up slower. Leave null to use the AME default, `OFF`. Requires provider >= 0.12.0."
  type        = string
  default     = null

  validation {
    condition = var.security_updates_on_join == null || contains([
      "OFF",
      "INSTALL",
      "INSTALL_AND_REBOOT",
    ], coalesce(var.security_updates_on_join, "OFF"))
    error_message = "security_updates_on_join must be one of OFF, INSTALL, INSTALL_AND_REBOOT, or null."
  }
}

variable "taints" {
  description = "Kubernetes taints applied to every node in the pool, so that only pods with a matching toleration are scheduled onto it. `effect` must be one of `NoSchedule`, `PreferNoSchedule` or `NoExecute`."
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []

  validation {
    condition = alltrue([
      for t in var.taints : contains(["NoSchedule", "PreferNoSchedule", "NoExecute"], t.effect)
    ])
    error_message = "Each taint effect must be NoSchedule, PreferNoSchedule or NoExecute."
  }
}

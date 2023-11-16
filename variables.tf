
variable "organisation_slug" {
  description = "A unique identifier for the organisation. This is used to distinguish resources across different organisations. Required."
  type        = string
  nullable    = false
}

variable "environment_slug" {
  description = "A unique identifier for the environment within the organisation. Required."
  type        = string
  nullable    = false
}

variable "cluster_slug" {
  type        = string
  description = "Slug of the cluster"
}

variable "name" {
  type = string
  description = "name of the node pool"
  default = "worker"
}

variable "enable_multi_availability_zones" {
  type        = bool
  default     = false
  description = "deploy the node pool in all availability zones within the Cluster's cloud provider region"
}

variable "node_count" {
  type        = number
  description = "Number of machines in the node pool"
  default     = 1
}

variable "node_size" {
  type        = string
  description = "Machine Size for nodes in the worker pool"
}

variable "labels" {
  description = "Custom node labels for nodes within the node pool"
  default     = {}
}

variable "annotations" {
  description = "Custom node annotations for nodes within the node pool"
  default     = {}
}

variable "enable_auto_healing" {
  description = "Enable node auto healing for nodes in the node pool"
  default     = true
}

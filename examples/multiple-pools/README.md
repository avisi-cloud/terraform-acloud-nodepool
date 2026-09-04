# Several node pools from one map

Calling the module once per entry in a map, with `for_each`. This is how you build a differentiated
cluster from this module directly, and it is exactly what
[`avisi-cloud/cluster/acloud`](https://registry.terraform.io/modules/avisi-cloud/cluster/acloud/latest)
does internally with its `node_pools` input.

## What it creates

Three pools with different shapes, on a three-zone region:

| Pool | Zones | `node_count` | Machines |
| --- | --- | --- | --- |
| `system` | all three | 1 per zone | 3 × `t3.medium` |
| `apps` | all three | 2 per zone | 6 × `t3.large` |
| `data` | `eu-west-1a` only | 3 | 3 × `t3.large` |
| | | | **12 machines total** |

Mixing fanned-out and pinned pools in one map is the point: `data` sets
`enable_multi_availability_zones = false` so it stays in one zone, while the others spread.

## The interesting bits

```hcl
variable "node_pools" {
  type = map(object({
    node_size                       = string
    node_count                      = optional(number, 1)
    enable_multi_availability_zones = optional(bool, true)
    availability_zone               = optional(string, "")
    labels                          = optional(map(string), {})
  }))
  # ... defaults define system / apps / data
}

module "node_pool" {
  source   = "../../"
  for_each = var.node_pools

  name                            = each.key
  node_size                       = each.value.node_size
  node_count                      = each.value.node_count
  enable_multi_availability_zones = each.value.enable_multi_availability_zones
  availability_zone               = each.value.availability_zone
  labels                          = each.value.labels
}
```

The `optional(...)` defaults in the object type give each pool the same "override only what differs"
feel as the cluster module, but with a real type instead of `any` - so a typo in a pool key is a plan
error rather than a setting that silently does nothing.

State addresses nest two levels, pool name then zone:

```
module.node_pool["apps"].acloud_nodepool.pool["eu-west-1b"]
                  └ map key                    └ availability zone
```

## Prerequisites

An existing AME cluster, created with multi-AZ enabled if you want the fanned-out pools, and a
[Personal Access Token](https://docs.avisi.cloud/docs/product/tasks/how-to/personal-access-tokens).

## Running it

```sh
export TF_VAR_acloud_token="acpat_..."

terraform init
terraform apply \
  -var organisation_slug=example-org \
  -var environment_slug=production \
  -var cluster_slug=orders
```

Override the whole layout by passing your own `node_pools` map in a `.tfvars` file.

<!-- BEGIN_TF_DOCS -->
## Reference

Generated from the `.tf` files in this directory with [terraform-docs](https://terraform-docs.io).
Run `make docs` after changing any variable, output, resource or module block.

### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_acloud"></a> [acloud](#requirement\_acloud) | >= 0.12.0 |



### Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_node_pool"></a> [node\_pool](#module\_node\_pool) | ../../ | n/a |



### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_acloud_token"></a> [acloud\_token](#input\_acloud\_token) | Avisi Cloud Personal Access Token. Create one under API Access in the Console. | `string` | n/a | yes |
| <a name="input_cluster_slug"></a> [cluster\_slug](#input\_cluster\_slug) | Slug of the existing cluster to attach the node pool to. | `string` | n/a | yes |
| <a name="input_environment_slug"></a> [environment\_slug](#input\_environment\_slug) | Slug of the AME environment the cluster lives in. | `string` | n/a | yes |
| <a name="input_organisation_slug"></a> [organisation\_slug](#input\_organisation\_slug) | Slug of the Avisi Cloud organisation that owns the cluster. | `string` | n/a | yes |
| <a name="input_acloud_api"></a> [acloud\_api](#input\_acloud\_api) | Avisi Cloud API base URL. Leave null to use the public API at https://api.avisi.cloud. | `string` | `null` | no |
| <a name="input_cloud_provider"></a> [cloud\_provider](#input\_cloud\_provider) | Cloud provider slug the cluster runs on. | `string` | `"aws"` | no |
| <a name="input_node_pools"></a> [node\_pools](#input\_node\_pools) | Node pools to create, keyed by pool name. | <pre>map(object({<br/>    node_size                       = string<br/>    node_count                      = optional(number, 1)<br/>    enable_multi_availability_zones = optional(bool, true)<br/>    availability_zone               = optional(string, "")<br/>    labels                          = optional(map(string), {})<br/>  }))</pre> | <pre>{<br/>  "apps": {<br/>    "labels": {<br/>      "role": "apps"<br/>    },<br/>    "node_count": 2,<br/>    "node_size": "t3.large"<br/>  },<br/>  "data": {<br/>    "availability_zone": "eu-west-1a",<br/>    "enable_multi_availability_zones": false,<br/>    "labels": {<br/>      "role": "data"<br/>    },<br/>    "node_count": 3,<br/>    "node_size": "t3.large"<br/>  },<br/>  "system": {<br/>    "labels": {<br/>      "role": "system"<br/>    },<br/>    "node_size": "t3.medium"<br/>  }<br/>}</pre> | no |
| <a name="input_region"></a> [region](#input\_region) | Region the cluster is deployed in. | `string` | `"eu-west-1"` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_node_pools"></a> [node\_pools](#output\_node\_pools) | Created node pools, keyed by pool name and then by availability zone. |
<!-- END_TF_DOCS -->

# Single-zone node pool

One node pool, pinned to one availability zone, attached to a cluster that already exists. With
multi-zone off there is no fan-out, so `node_count` is the literal number of machines you get.

Use this shape for stateful workloads that should stay in one zone, close to their volumes, and as
the simplest way to see what the module does.

## What it creates

| | |
| --- | --- |
| `acloud_nodepool` | 1, in `eu-west-1a` |
| Machines | **3** × `t3.large` |
| Node label | `role=data` |

## The interesting bits

```hcl
module "node_pool" {
  source = "../../"    # use "avisi-cloud/nodepool/acloud" outside this repo

  # No fan-out: exactly one pool, in the zone named below.
  enable_multi_availability_zones = false
  availability_zone               = var.availability_zone

  name       = "data"
  node_size  = "t3.large"
  node_count = 3        # 3 machines, not 3 per zone

  labels = { "role" = "data" }
}
```

Setting `availability_zone` explicitly also gives the pool a readable state address -
`module.node_pool.acloud_nodepool.pool["eu-west-1a"]`. Leave it at its empty default and the key
becomes `""`, which is awkward to work with in `terraform state` commands.

Note that `cloud_provider` and `region` are still required even though nothing fans out. They are
only used to look up the region's availability zones, and must match the cluster's own placement.

## Prerequisites

An existing AME cluster, and a
[Personal Access Token](https://docs.avisi.cloud/docs/product/tasks/how-to/personal-access-tokens).
The organisation, environment and cluster slugs are on the cluster page in the Console.

## Running it

```sh
export TF_VAR_acloud_token="acpat_..."

terraform init
terraform apply \
  -var organisation_slug=example-org \
  -var environment_slug=production \
  -var cluster_slug=orders
```

<!-- BEGIN_TF_DOCS -->
## Reference

Generated from the `.tf` files in this directory with [terraform-docs](https://terraform-docs.io).
Run `make docs` after changing any variable, output, resource or module block.

### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_acloud"></a> [acloud](#requirement\_acloud) | >= 0.10.1 |



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
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | Availability zone to place the node pool in. Must be a zone within `region`. | `string` | `"eu-west-1a"` | no |
| <a name="input_cloud_provider"></a> [cloud\_provider](#input\_cloud\_provider) | Cloud provider slug the cluster runs on. | `string` | `"aws"` | no |
| <a name="input_region"></a> [region](#input\_region) | Region the cluster is deployed in. | `string` | `"eu-west-1"` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_node_pool"></a> [node\_pool](#output\_node\_pool) | Created node pools, keyed by availability zone. |
<!-- END_TF_DOCS -->

# Multi-zone node pool

One node pool spread across **every** availability zone in the cluster's region. This is the module's
headline feature, and the one whose arithmetic catches people out.

## What it creates

Because multi-zone is enabled, the module creates one node pool per availability zone. The figures
below assume a three-zone region:

| | |
| --- | --- |
| `acloud_nodepool` | one per zone the region publishes - three in a three-zone region |
| `node_count` | 2 **per zone** |
| Machines | **6** × `t3.medium` in a three-zone region |

The zone list comes from AME rather than from the cloud provider directly: a region only fans out if
AME publishes availability zones against that exact region slug, and a provider's multi-zone region
may be published under a slug of its own. Confirm with `acloud cloud-providers get` before assuming
a count. If the region returns no zones at all, the module now fails at plan time instead of quietly
creating nothing.

> **Important:**
> `node_count = 2` does not mean two machines. It means two machines *in every zone*. Halve the
> count, or switch to [`examples/single-zone`](../single-zone), if that is more capacity than you
> want.

## The interesting bits

```hcl
module "node_pool" {
  source = "../../"

  # Fan out: one acloud_nodepool per availability zone in `region`.
  enable_multi_availability_zones = true

  name       = "apps"
  node_size  = "t3.medium"
  node_count = 2        # per zone -> 6 machines in a three-zone region

  labels = { "role" = "apps" }
}
```

`availability_zone` is deliberately not set here - it is ignored when multi-zone is on, because the
pool is created in every zone regardless.

The example also outputs `availability_zones`, which is just `keys(module.node_pool.node_pool)` - a
quick way to confirm what the region actually resolved to before you scale the pool up.

## Prerequisites

An existing AME cluster **that was created with multi-AZ enabled**, in a region that has more than
one zone. Multi-AZ is a cluster setting that
[cannot be changed after creation](https://docs.avisi.cloud/docs/product/tasks/kubernetes/create-a-new-cluster),
and Hetzner regions are single-zone, so this shape does not apply there.

Plus a [Personal Access Token](https://docs.avisi.cloud/docs/product/tasks/how-to/personal-access-tokens).

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
| <a name="input_region"></a> [region](#input\_region) | Region the cluster is deployed in. Its availability zones determine the fan-out. | `string` | `"eu-west-1"` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_availability_zones"></a> [availability\_zones](#output\_availability\_zones) | The zones the pool was fanned out over. |
| <a name="output_node_pool"></a> [node\_pool](#output\_node\_pool) | Created node pools, keyed by availability zone. |
<!-- END_TF_DOCS -->

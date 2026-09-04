# Autoscaled, tainted batch pool

A dedicated node pool that exercises everything the module can configure beyond size and labels:
**autoscaling**, **taints**, an explicit **upgrade strategy**, and **security updates on join**.

Use this shape for bursty or isolated workloads - CI runners, batch jobs, anything that should scale
to zero when idle and never share nodes with general application traffic.

## What it creates

| | |
| --- | --- |
| `acloud_nodepool` | 1, in `eu-west-1a` |
| Size | autoscaled between **0 and 10** × `t3.large` |
| Taint | `dedicated=batch:NoSchedule` |
| Upgrades | `INPLACE` - drain and upgrade, do not replace |
| Node bring-up | `INSTALL_AND_REBOOT` - patched before joining |

Multi-zone is off on purpose: with fan-out enabled, `min_size` and `max_size` apply to *each zone's*
pool, so a 0-10 range across three zones is really 0-30 machines.

## The interesting bits

```hcl
enable_auto_scaling = true
min_size            = 0     # scale to zero when idle
max_size            = 10
node_count          = 1     # starting size

taints = [
  { key = "dedicated", value = "batch", effect = "NoSchedule" },
]

security_updates_on_join = "INSTALL_AND_REBOOT"
upgrade_strategy         = "INPLACE"
```

Workloads must tolerate the taint to land here:

```yaml
tolerations:
  - key: dedicated
    value: batch
    effect: NoSchedule
```

> [!IMPORTANT]
> `security_updates_on_join = "INSTALL_AND_REBOOT"` is not decoration on an autoscaled pool. Without
> it, nodes join unpatched, get patched the next morning and are drained to reboot; the evicted pods
> make the autoscaler add another unpatched node, and the rebooted node comes back empty and is
> scaled down. The pool then recycles every node, every day. See the
> [runbook](https://docs.avisi.cloud/docs/runbooks/debug/new-nodes-require-reboot-after-join).

The trade-off is bring-up time: installing updates and rebooting means a new node takes longer to
become Ready, so the pool reacts more slowly to a sudden spike in demand. See
[Nodes That Join Fully Patched](https://docs.avisi.cloud/blog/security-updates-on-join) for the
reasoning, and the
[reference docs](https://docs.avisi.cloud/docs/product/overview/kubernetes/security-updates-on-join)
for the full behaviour.

## Prerequisites

An existing AME cluster, a provider **>= 0.12.0** (that is when `security_updates_on_join` landed),
and a [Personal Access Token](https://docs.avisi.cloud/docs/product/tasks/how-to/personal-access-tokens).

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
| <a name="module_batch"></a> [batch](#module\_batch) | ../../ | n/a |



### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_acloud_token"></a> [acloud\_token](#input\_acloud\_token) | Avisi Cloud Personal Access Token. Create one under API Access in the Console. | `string` | n/a | yes |
| <a name="input_cluster_slug"></a> [cluster\_slug](#input\_cluster\_slug) | Slug of the existing cluster to attach the node pool to. | `string` | n/a | yes |
| <a name="input_environment_slug"></a> [environment\_slug](#input\_environment\_slug) | Slug of the AME environment the cluster lives in. | `string` | n/a | yes |
| <a name="input_organisation_slug"></a> [organisation\_slug](#input\_organisation\_slug) | Slug of the Avisi Cloud organisation that owns the cluster. | `string` | n/a | yes |
| <a name="input_acloud_api"></a> [acloud\_api](#input\_acloud\_api) | Avisi Cloud API base URL. Leave null to use the public API at https://api.avisi.cloud. | `string` | `null` | no |
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | Availability zone for the batch pool. Must be a zone within `region`. | `string` | `"eu-west-1a"` | no |
| <a name="input_cloud_provider"></a> [cloud\_provider](#input\_cloud\_provider) | Cloud provider slug the cluster runs on. | `string` | `"aws"` | no |
| <a name="input_region"></a> [region](#input\_region) | Region the cluster is deployed in. | `string` | `"eu-west-1"` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_node_pool"></a> [node\_pool](#output\_node\_pool) | Created node pools, keyed by availability zone. |
<!-- END_TF_DOCS -->

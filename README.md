# Avisi Cloud Kubernetes Node Pool

[![Terraform Registry](https://img.shields.io/badge/terraform-registry-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/modules/avisi-cloud/nodepool/acloud/latest)
[![Provider](https://img.shields.io/badge/provider-avisi--cloud%2Facloud-5C4EE5?logo=terraform&logoColor=white)](https://registry.terraform.io/providers/avisi-cloud/acloud/latest)
[![Product docs](https://img.shields.io/badge/docs-avisi.cloud-0F6FFF)](https://docs.avisi.cloud/)

Terraform module that attaches a
**[node pool](https://docs.avisi.cloud/docs/product/overview/kubernetes/node-pool)** to an existing
[Avisi Managed Environments (AME)](https://docs.avisi.cloud/docs/product/why-ame) Kubernetes cluster,
optionally spreading it across every availability zone in the cluster's region.

A node pool is a group of machines that share one configuration - machine type, labels, annotations
and auto-healing behaviour - and join your cluster as Kubernetes nodes. This module creates one, or
one per availability zone, from a single `module` block.

```hcl
module "workers" {
  source  = "avisi-cloud/nodepool/acloud"
  version = "0.1.0"

  organisation_slug = "example-org"
  environment_slug  = "production"
  cluster_slug      = "orders"
  cloud_provider    = "aws"
  region            = "eu-west-1"

  name       = "workers"
  node_size  = "t3.medium"
  node_count = 2
}
```

---

## Contents

- [Overview](#overview)
- [When to use this module](#when-to-use-this-module)
- [Requirements](#requirements)
- [Usage](#usage)
- [How availability zones work](#how-availability-zones-work)
- [Understanding the inputs](#understanding-the-inputs)
- [Scaling, scheduling and lifecycle](#scaling-scheduling-and-lifecycle)
- [Consuming the output](#consuming-the-output)
- [Examples](#examples)
- [Known rough edges](#known-rough-edges)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Related documentation](#related-documentation)
- [Reference](#reference) *(generated)*

---

## Overview

The module looks up the availability zones of the cluster's region, then creates node pools:

```
 inputs                          module                            AME objects
 ──────                          ──────                            ───────────

 organisation_slug ─┐
 cloud_provider ────┼──▶ data.acloud_cloud_provider_availability_zones
 region ────────────┘                    │
                                         │ ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
                                         ▼
 enable_multi_availability_zones ──▶  for_each  ──────────────▶ acloud_nodepool
 name / node_size / node_count ───▶      │                       one per zone
 labels / annotations ────────────▶      │                       (or one, pinned
 enable_auto_healing ─────────────▶      │                        to availability_zone)
                                         ▼
                                  output.node_pool
                                  map keyed by zone
```

| The module creates | Count |
| --- | --- |
| `acloud_nodepool` | One per availability zone when multi-zone is on, otherwise exactly one |

It does **not** create the organisation, environment or cluster - all three must already exist.

## When to use this module

**Use it directly** when you already have a cluster and want to add node pools to it, or when you
want pools that differ from each other in size, labels or zone placement. Calling it once per pool
with `for_each` is the intended pattern - see [`examples/multiple-pools`](https://github.com/avisi-cloud/terraform-acloud-nodepool/tree/main/examples/multiple-pools).

**You may already be using it indirectly.** The
[`avisi-cloud/cluster/acloud`](https://registry.terraform.io/modules/avisi-cloud/cluster/acloud/latest)
module calls this one once per entry in its `node_pools` map. If you provision clusters with that
module, this is where its node pools actually come from - which is also why its `node_count` is a
per-zone number.

**Reach for the [`acloud_nodepool` resource](https://registry.terraform.io/providers/avisi-cloud/acloud/latest/docs/resources/nodepool)
directly when** you need a distinct pool name per availability zone. Everything else the resource
offers - autoscaling, taints, upgrade strategy, security updates on join - is an input here.

## Requirements

| | Version |
| --- | --- |
| Terraform | **`>= 1.2.0`**, declared by the module. The binding constraint is the data source postcondition that guards against a region with no availability zones |
| `avisi-cloud/acloud` provider | **`>= 0.12.0`** - the release that added `security_updates_on_join` |

In Avisi Cloud you need an existing cluster, and a
[Personal Access Token](https://docs.avisi.cloud/docs/product/tasks/how-to/personal-access-tokens)
for the provider. The organisation, environment and cluster slugs are all visible on the cluster page
in the [Console](https://console.avisi.cloud/).

## Usage

### A single pool in one zone

```hcl
module "data" {
  source  = "avisi-cloud/nodepool/acloud"
  version = "0.1.0"

  organisation_slug = "example-org"
  environment_slug  = "production"
  cluster_slug      = "orders"
  cloud_provider    = "aws"
  region            = "eu-west-1"

  enable_multi_availability_zones = false
  availability_zone               = "eu-west-1a"

  name       = "data"
  node_size  = "t3.large"
  node_count = 3          # exactly 3 machines, all in eu-west-1a

  labels = { role = "data" }
}
```

### Spread across every zone

```hcl
module "apps" {
  source  = "avisi-cloud/nodepool/acloud"
  version = "0.1.0"

  organisation_slug = "example-org"
  environment_slug  = "production"
  cluster_slug      = "orders"
  cloud_provider    = "aws"
  region            = "eu-west-1"

  enable_multi_availability_zones = true

  name       = "apps"
  node_size  = "t3.medium"
  node_count = 2          # 2 machines PER ZONE - six in a three-zone region

  labels = { role = "apps" }
}
```

## How availability zones work

This is the behaviour that surprises people, so it is worth being precise about.

When `enable_multi_availability_zones` is `true`, the module asks AME for the availability zones of
`region` and creates **one `acloud_nodepool` per zone**, each sized `node_count`. When it is `false`,
it creates exactly one pool, placed in `availability_zone`.

For a region with three availability zones and `node_count = 2`:

| `enable_multi_availability_zones` | `acloud_nodepool` resources | Machines |
| --- | --- | --- |
| `true` | 3 - one in each zone | **6** |
| `false` *(module default)* | 1 - in `availability_zone` | **2** |

So `node_count` is *nodes per zone*, not nodes per pool.

> **Important:**
> The default here is `false`, but the `avisi-cloud/cluster/acloud` module passes `true` unless you
> override it. If you arrived from that module, multi-zone is on and your node counts are being
> multiplied.

Multi-zone placement is only useful on a cluster that was itself created with multi-AZ enabled, and
that is a cluster setting which
[cannot be changed after creation](https://docs.avisi.cloud/docs/product/tasks/kubernetes/create-a-new-cluster).
Regions also differ: Cyso `ams2` exposes three zones, while Hetzner regions are single-zone.

The zone list comes from AME rather than from the cloud provider directly, so a region only fans out
if AME publishes availability zones against that exact region slug - and a provider's multi-zone
region may be published under a slug of its own rather than under the plain cloud provider name.
Check with `acloud cloud-providers get`. If the region returns no zones, the module fails at plan
time with a message pointing at the region slug, rather than quietly creating no node pools at all.

The resulting Terraform addresses are keyed by zone, which is what you need for `terraform state`
operations and targeted plans:

```
module.apps.acloud_nodepool.pool["eu-west-1a"]
                                  └ availability zone

# with multi-zone disabled, the key is whatever `availability_zone` is set to,
# which is "" when it is left at the default:
module.data.acloud_nodepool.pool[""]
```

## Understanding the inputs

**Placement.** `organisation_slug`, `environment_slug` and `cluster_slug` identify the cluster to
attach to. All three are slugs, not display names, and the cluster must already exist.

**`cloud_provider` and `region` are not node pool attributes.** They are required only so the module
can look up the region's availability zones. They are never written to the `acloud_nodepool`
resource. They must still match the cluster's actual provider and region, or the fan-out will target
zones the cluster cannot use.

**`name`** becomes the AME node pool name and the Kubernetes node role label on every node in the
pool. With multi-zone enabled, every zone's pool is created with this same name.

**`node_count`** is per zone when multi-zone is enabled - see above.

**`labels` and `annotations`** are applied to every node in the pool. Labels drive scheduling through
`nodeSelector` and node affinity; annotations are usually read by automation. Both replace rather than
merge, so a caller that sets `labels` gets only what it passed.

**`enable_auto_healing`** maps to `node_auto_replacement`: AME replaces nodes it detects as unhealthy.
It defaults to `true`.

## Scaling, scheduling and lifecycle

Beyond size and labels, four inputs control how the pool behaves over its life.

### Autoscaling

By default the pool holds exactly `node_count` machines. Turn on `enable_auto_scaling` and AME's
cluster autoscaler sizes it on utilisation instead:

```hcl
enable_auto_scaling = true
min_size            = 0    # scale to zero when idle
max_size            = 10
```

`min_size` and `max_size` fall back to `node_count` when left null, which is the fixed-size behaviour
this module had before autoscaling was configurable.

It is worth knowing how a pool actually gets sized, because `node_count` is not what it looks like.
The provider never sends a node count to AME. It sends `min_size` and `max_size`, and when
`auto_scaling` is false it overwrites both with `node_count` first:

| | What sizes the pool |
| --- | --- |
| `enable_auto_scaling = false` | `node_count`, used as the minimum and maximum together |
| `enable_auto_scaling = true` | `min_size` and `max_size`. **`node_count` is ignored** - it is not a starting size |

> **Important:**
> With multi-zone enabled the bounds apply to **each zone's pool**, not to the pool as a whole. A
> `0`-`10` range across three zones is really 0 to 30 machines. Pin autoscaled pools to a single zone
> unless you mean that.

### Taints

Keep a pool for specific workloads by tainting it, so only pods carrying a matching toleration are
scheduled there:

```hcl
taints = [
  { key = "dedicated", value = "batch", effect = "NoSchedule" },
]
```

`effect` must be `NoSchedule`, `PreferNoSchedule` or `NoExecute`; the module validates this.

### Upgrade strategy

How nodes move to a new AME version. This input defaults to
`REPLACE_MINOR_INPLACE_PATCH_WITHOUT_DRAIN`, which is AME's own default for a normal cluster, and it
is **always sent** - it cannot be left unset.

> **Important:**
> The reason it is always sent is a provider constraint, not a preference. From provider 0.8.0
> onwards, `acloud_nodepool` parses `upgrade_strategy` unconditionally when it creates a pool and
> rejects the empty string that an unset value produces, failing the apply with
> `cannot parse upgradeStrategy: unsupported upgrade strategy:`. Earlier versions of this module
> left the attribute out and hit exactly that. Two consequences worth knowing:
>
> - On a **Bring Your Own Node** cluster AME's own default is `INPLACE`, not the value above. Set
>   `upgrade_strategy = "INPLACE"` explicitly on BYON pools so the module's default does not
>   override it.
> - The provider does not include this attribute in its **update** payload, and does not read it
>   back, so changing the strategy on an existing pool does not take effect until the pool is
>   recreated.

The product documentation spells these values in camelCase
(`replaceMinorInplacePatchWithoutDrain`); the API and this module take the uppercase form below, and
match it case-sensitively.

| Value | Behaviour | Suits |
| --- | --- | --- |
| `REPLACE` | Always provision replacement nodes | Critical workloads that want a clean slate |
| `REPLACE_MINOR_INPLACE_PATCH` | Replace on minor upgrades, patch in place after draining | Work that tolerates a drain on patches |
| `REPLACE_MINOR_INPLACE_PATCH_WITHOUT_DRAIN` | As above, but patches without draining | **The default here, and AME's own for normal clusters.** General-purpose services |
| `INPLACE` | Always upgrade in place, after draining | Job-based work that reschedules cleanly |
| `INPLACE_WITHOUT_DRAIN` | Always upgrade in place, without draining | Stateful services and long-lived connections |

AME uses a surge strategy when replacing: a new node joins and passes health checks before an old one
is drained and removed. See
[upgrade strategies](https://docs.avisi.cloud/docs/product/overview/kubernetes/upgrades#upgrade-strategies).

### Security updates on join

Nodes boot from a base image whose OS packages lag behind. `security_updates_on_join` installs the
security updates during bring-up, **before** the node joins:

| Value | Behaviour |
| --- | --- |
| `OFF` | Nodes join with the base image packages. The AME default |
| `INSTALL` | Updates are installed, then the node joins |
| `INSTALL_AND_REBOOT` | Updates are installed, the node reboots if they require it, then it joins |

AME recommends `INSTALL_AND_REBOOT`, and states it will become the default once the feature leaves
beta. It applies only to a node's first join - newly provisioned nodes, replacement nodes after
auto-healing or a replace upgrade, and nodes added by the autoscaler - never to nodes already in the
cluster. It also makes bring-up slower, which matters for autoscaled pools that need to react
quickly.

> **Important:**
> This is a **beta** feature. AME documents that its values and defaults can still change, so treat
> anything here as current behaviour rather than a stable contract. It also needs an AME release
> that supports it: provider `>= 0.12.0` is necessary but not sufficient, and a cluster on an older
> AME version may reject or ignore the setting.

Background and the reasoning behind it:
[Nodes That Join Fully Patched](https://docs.avisi.cloud/blog/security-updates-on-join) (blog) and the
[reference documentation](https://docs.avisi.cloud/docs/product/overview/kubernetes/security-updates-on-join).

> **Caution:**
> **Autoscaling plus automatic node reboots, on a pool whose nodes join unpatched, recycles the whole
> pool daily.** A node joins, is patched the next morning, and is drained to reboot; the evicted pods
> make the autoscaler add another unpatched node, and the rebooted node comes back empty and is
> scaled down. Setting `security_updates_on_join = "INSTALL_AND_REBOOT"` removes the cause. See the
> [runbook](https://docs.avisi.cloud/docs/runbooks/debug/new-nodes-require-reboot-after-join).

### What is still left to AME

**Automatic node reboots** are configured on the cluster's *Patching* page in the Console, not through
Terraform. So is the reboot window.

## Consuming the output

`node_pool` is the full `acloud_nodepool` resource **as a map keyed by availability zone**, not a
single object - because multi-zone mode creates several. Index it or iterate it:

```hcl
# every pool identity, across all zones
output "identities" {
  value = [for zone, pool in module.apps.node_pool : pool.identity]
}

# the zones the pool landed in
output "zones" {
  value = keys(module.apps.node_pool)
}

# a specific zone
output "one" {
  value = module.apps.node_pool["eu-west-1a"].identity
}
```

With multi-zone disabled the map still has one entry, keyed by whatever `availability_zone` is -
`""` when left at the default.

## Examples

| Example | Shows |
| --- | --- |
| [`examples/single-zone`](https://github.com/avisi-cloud/terraform-acloud-nodepool/tree/main/examples/single-zone) | One pool pinned to one availability zone; `node_count` is the literal machine count |
| [`examples/autoscaling`](https://github.com/avisi-cloud/terraform-acloud-nodepool/tree/main/examples/autoscaling) | Autoscaling, taints, upgrade strategy and security updates on join together |
| [`examples/multi-zone`](https://github.com/avisi-cloud/terraform-acloud-nodepool/tree/main/examples/multi-zone) | Fan-out across every zone in the region, and the resulting machine math |
| [`examples/multiple-pools`](https://github.com/avisi-cloud/terraform-acloud-nodepool/tree/main/examples/multiple-pools) | `for_each` over a map of pools - the pattern `avisi-cloud/cluster/acloud` uses internally |

Each example is a standalone root module:

```sh
cd examples/multi-zone
export TF_VAR_acloud_token="acpat_..."
terraform init
terraform apply -var organisation_slug=... -var environment_slug=... -var cluster_slug=...
```

## Known rough edges

Honest list of things that are true of the current module.

| | Impact | Workaround |
| --- | --- | --- |
| Multi-zone fan-out reuses the pool name for every zone | Each zone's pool is submitted with the same `name` and differs only by `availability_zone`. The provider's own multi-AZ examples use distinct names per zone (`workers-a`, `workers-b`, `workers-c`) instead | Declare `acloud_nodepool` directly if you need per-zone names |
| Several attributes are creation-time only in practice | The provider omits `name`, `auto_scaling`, `node_auto_replacement` and `upgrade_strategy` from its update payload, and never reads `upgrade_strategy` back. Changing any of them on an existing pool has no effect and may not even show as a diff | Recreate the pool, or make the change in the Console |
| `delete`/`create` is the only way to resize an autoscaled pool's bounds downward reliably | `min_size` and `max_size` are sent on update, but `auto_scaling` itself is not, so a pool cannot be switched between fixed and autoscaled after creation | Recreate the pool |
| `cloud_provider` and `region` are required but never written to the pool | Easy to read as node pool attributes when they only feed the zone lookup | Documented above; they must still match the cluster |
| Single-zone pools key state on `""` by default | `module.x.acloud_nodepool.pool[""]` is an odd address to work with | Set `availability_zone` explicitly for a readable key |
| Provider floor raised to `>= 0.12.0` | Required by `security_updates_on_join`. Configurations pinned to an older provider will not resolve | Upgrade the provider; 0.12.0 is from September 2026 |
| Autoscaler bounds are per zone under multi-zone | `min_size`/`max_size` apply to each zone's pool, so the totals multiply | Pin autoscaled pools to one availability zone |

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| More machines than expected | Multi-zone fan-out - `node_count` is per availability zone |
| `for_each` produced one pool keyed `""` | `enable_multi_availability_zones` is `false` and `availability_zone` was left at its empty default |
| Nodes never join, or the pool is rejected | `cloud_provider` / `region` do not match the cluster, so the zones do not exist for it |
| Machine type rejected | `node_size` is not offered in that region for the cluster's cloud account. Check with `acloud cloud-providers get` |
| Changing `availability_zone` forces replacement | It can only be set at creation time on `acloud_nodepool` |
| 401 / 403 from the API | The PAT is invalid, expired, CIDR-restricted, or lacks access to the organisation |

## Contributing

Development setup, the `make` workflow, how the generated README blocks work, and the release
process live in [CONTRIBUTING.md](https://github.com/avisi-cloud/terraform-acloud-nodepool/blob/main/CONTRIBUTING.md).

One consequence is worth repeating here, because it catches people out: **the Registry's Inputs tab
is generated from the `variable` blocks, not from this README.** Improving how an input is
documented means editing its `description` in `variables.tf` and running `make docs`.

## Related documentation

**Avisi Cloud**

- [Node pools](https://docs.avisi.cloud/docs/product/overview/kubernetes/node-pool) · [Create a node pool](https://docs.avisi.cloud/docs/product/tasks/kubernetes/create-a-new-nodepool) · [Scale a node pool](https://docs.avisi.cloud/docs/product/tasks/kubernetes/scale-node-pool)
- [Autoscaling](https://docs.avisi.cloud/docs/product/overview/kubernetes/autoscaler) · [Upgrades and upgrade strategies](https://docs.avisi.cloud/docs/product/overview/kubernetes/upgrades) · [Node recycling](https://docs.avisi.cloud/docs/product/overview/kubernetes/node-recycling)
- [Security updates on join](https://docs.avisi.cloud/docs/product/overview/kubernetes/security-updates-on-join) · [announcement blog](https://docs.avisi.cloud/blog/security-updates-on-join) · [Scale node pools to zero](https://docs.avisi.cloud/docs/product/overview/kubernetes/scale-node-pools-to-zero)
- [Terraform provider guide](https://docs.avisi.cloud/docs/development/terraform/terraform) · [Personal Access Tokens](https://docs.avisi.cloud/docs/product/tasks/how-to/personal-access-tokens) · [`acloud` CLI](https://docs.avisi.cloud/docs/cli)

**Terraform**

- [This module on the Registry](https://registry.terraform.io/modules/avisi-cloud/nodepool/acloud/latest) · [Cluster module](https://registry.terraform.io/modules/avisi-cloud/cluster/acloud/latest) · [`acloud_nodepool` resource](https://registry.terraform.io/providers/avisi-cloud/acloud/latest/docs/resources/nodepool)
- [Provider source and examples](https://github.com/avisi-cloud/terraform-provider-acloud)

<!-- BEGIN_TF_DOCS -->
## Reference

Generated from the `.tf` files in this directory with [terraform-docs](https://terraform-docs.io).
Run `make docs` after changing any variable, output, resource or module block.

### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.0 |
| <a name="requirement_acloud"></a> [acloud](#requirement\_acloud) | >= 0.12.0 |

### Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_acloud"></a> [acloud](#provider\_acloud) | >= 0.12.0 |



### Resources

| Name | Type |
| ---- | ---- |
| [acloud_nodepool.pool](https://registry.terraform.io/providers/avisi-cloud/acloud/latest/docs/resources/nodepool) | resource |
| [acloud_cloud_provider_availability_zones.zones](https://registry.terraform.io/providers/avisi-cloud/acloud/latest/docs/data-sources/cloud_provider_availability_zones) | data source |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cloud_provider"></a> [cloud\_provider](#input\_cloud\_provider) | Slug of the AME cloud provider the cluster runs on, for example `aws`, `hetzner` or `cyso-cloud-ams2`. Used together with `region` to look up the region's availability zones - it is not an attribute of the node pool itself. Run `acloud cloud-providers get` to list the slugs available to your organisation. | `string` | n/a | yes |
| <a name="input_cluster_slug"></a> [cluster\_slug](#input\_cluster\_slug) | Slug of the cluster to attach the node pool to. AME derives this from the cluster's display name; it is the identifier shown on the cluster page and used by `acloud` commands. Can only be set at creation time. | `string` | n/a | yes |
| <a name="input_environment_slug"></a> [environment\_slug](#input\_environment\_slug) | Slug of the AME environment the cluster lives in. An environment groups clusters inside an organisation, for example `production` or `staging`. | `string` | n/a | yes |
| <a name="input_node_size"></a> [node\_size](#input\_node\_size) | Cloud provider machine type for nodes in the pool, for example `t3.medium` (AWS), `cx33` (Hetzner) or `s5.small` (Cyso Cloud AMS2). The type must be offered in `region` for the cluster's cloud account. | `string` | n/a | yes |
| <a name="input_organisation_slug"></a> [organisation\_slug](#input\_organisation\_slug) | Slug of the Avisi Cloud organisation that owns the cluster. This is the short identifier used in Console URLs and API paths, not the display name. Run `acloud config get-organisations` to list the slugs you have access to. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Slug of the cloud provider region the cluster is deployed in, for example `eu-west-1`, `fsn1` or `ams2`. Used together with `cloud_provider` to look up the region's availability zones. Must match the region the cluster was created in. | `string` | n/a | yes |
| <a name="input_annotations"></a> [annotations](#input\_annotations) | Kubernetes node annotations applied to every node in the pool. Typically consumed by automation rather than by the scheduler. | `map(string)` | `{}` | no |
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | Availability zone for the node pool when `enable_multi_availability_zones` is false, for example `eu-west-1a`. Ignored when multi-zone is enabled, because the pool is then created in every zone. The empty default lets AME place the pool. Can only be set at creation time. | `string` | `""` | no |
| <a name="input_enable_auto_healing"></a> [enable\_auto\_healing](#input\_enable\_auto\_healing) | Let AME automatically replace nodes in this pool that it detects as unhealthy. Maps to `node_auto_replacement` on the underlying `acloud_nodepool` resource. Note that the provider does not send this attribute when it updates an existing pool, so changing it afterwards has no effect until the pool is recreated. | `bool` | `true` | no |
| <a name="input_enable_auto_scaling"></a> [enable\_auto\_scaling](#input\_enable\_auto\_scaling) | Let the AME cluster autoscaler size this node pool based on utilisation, between `min_size` and `max_size`. When false, the pool stays at `node_count` machines. Note that the provider does not send this attribute when it updates an existing pool, so turning autoscaling on or off afterwards has no effect until the pool is recreated. | `bool` | `false` | no |
| <a name="input_enable_multi_availability_zones"></a> [enable\_multi\_availability\_zones](#input\_enable\_multi\_availability\_zones) | Create one node pool in every availability zone of `region` instead of a single pool. Each zone's pool is sized `node_count`, so the machine count is `node_count` multiplied by the number of zones. When false, a single pool is created in `availability_zone`. | `bool` | `false` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Kubernetes node labels applied to every node in the pool. Use them for scheduling with `nodeSelector` or node affinity. | `map(string)` | `{}` | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Maximum number of machines the autoscaler may scale the pool up to. Only used when `enable_auto_scaling` is true; with autoscaling off the provider pins the bounds to `node_count`. Defaults to `node_count` when null. With `enable_multi_availability_zones` enabled this bound applies to *each zone's* pool, so the cluster-wide maximum is this value multiplied by the number of zones. | `number` | `null` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Minimum number of machines the autoscaler may scale the pool down to. Only used when `enable_auto_scaling` is true; with autoscaling off the provider pins the bounds to `node_count`. Defaults to `node_count` when null. With `enable_multi_availability_zones` enabled this bound applies to *each zone's* pool, so the cluster-wide minimum is this value multiplied by the number of zones. | `number` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the node pool. AME uses it for the Kubernetes node role label on every node in the pool. With `enable_multi_availability_zones` enabled, the same name is used for each zone's pool - they differ only by availability zone. Note that the provider does not send the name when it updates an existing pool, so renaming a pool has no effect until it is recreated. | `string` | `"worker"` | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | Number of machines in the node pool. With `enable_multi_availability_zones` enabled this is the count *per availability zone*, so the pool provisions this many nodes in every zone of the region. This sizes the pool only while `enable_auto_scaling` is false: the provider never sends a node count to AME, it sends `min_size` and `max_size` and pins both to this value when autoscaling is off. With autoscaling on, the pool is sized by `min_size` and `max_size` and this value is ignored. | `number` | `1` | no |
| <a name="input_security_updates_on_join"></a> [security\_updates\_on\_join](#input\_security\_updates\_on\_join) | Whether OS security updates are installed while a node is provisioned, before it joins the cluster. `OFF` joins with the base image packages; `INSTALL` installs updates first; `INSTALL_AND_REBOOT` also reboots when the updates require it. AME recommends `INSTALL_AND_REBOOT`, and states it will become the default once the feature leaves beta. Applies only to a node's first join, never to existing nodes, and it makes bring-up slower. This is a beta feature: AME documents that its values and defaults can still change, and it needs an AME release that supports it, not only provider >= 0.12.0. Leave null to send nothing, which the provider turns into `OFF`. | `string` | `null` | no |
| <a name="input_taints"></a> [taints](#input\_taints) | Kubernetes taints applied to every node in the pool, so that only pods with a matching toleration are scheduled onto it. `effect` must be one of `NoSchedule`, `PreferNoSchedule` or `NoExecute`. | <pre>list(object({<br/>    key    = string<br/>    value  = string<br/>    effect = string<br/>  }))</pre> | `[]` | no |
| <a name="input_upgrade_strategy"></a> [upgrade\_strategy](#input\_upgrade\_strategy) | How nodes in this pool are upgraded. `REPLACE` always provisions replacement nodes; `REPLACE_MINOR_INPLACE_PATCH` replaces on minor upgrades and patches in place after draining; `REPLACE_MINOR_INPLACE_PATCH_WITHOUT_DRAIN` does the same without draining; `INPLACE` always upgrades in place after draining; `INPLACE_WITHOUT_DRAIN` upgrades in place without draining. This value is always sent to AME and cannot be left unset: the provider rejects an empty upgrade strategy when it creates the node pool. The default here matches AME's own default for normal clusters; on a Bring Your Own Node cluster AME would default to `INPLACE` instead, so set that explicitly on a BYON pool. The product documentation spells these values in camelCase (`replaceMinorInplacePatchWithoutDrain`), but the API and this module take the uppercase form, and it is matched case-sensitively. Note that the provider does not send this attribute when it updates an existing pool, so changing it afterwards has no effect until the pool is recreated. | `string` | `"REPLACE_MINOR_INPLACE_PATCH_WITHOUT_DRAIN"` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_availability_zones"></a> [availability\_zones](#output\_availability\_zones) | The availability zones the pool was created in, as a sorted list. With multi-zone enabled this is every zone in the region; with it disabled it is the single `availability_zone`. |
| <a name="output_node_pool"></a> [node\_pool](#output\_node\_pool) | The created node pools, as a map keyed by availability zone. Each value is the full `acloud_nodepool` resource, so `identity`, `name`, `node_count` and the rest are available per zone. With multi-zone disabled the map has a single entry, keyed by `availability_zone`. |
<!-- END_TF_DOCS -->

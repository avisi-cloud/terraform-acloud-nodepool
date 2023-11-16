# Avisi Cloud Kubernetes Node Pool

This module deploys a Kubernetes Node Pool part of an [Avisi Cloud Kubernetes](https://docs.avisi.cloud/product/kubernetes/). It can automatically deploy node pools of the same type and configuration across all availability zones for a cluster.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_acloud"></a> [acloud](#requirement\_acloud) | >= 0.3.0 |

## Resources

| Name | Type |
|------|------|
| [acloud_nodepool.pool](https://registry.terraform.io/providers/avisi-cloud/acloud/latest/docs/resources/nodepool) | resource |
| [acloud_cloud_provider_availability_zones.zones](https://registry.terraform.io/providers/avisi-cloud/acloud/latest/docs/data-sources/cloud_provider_availability_zones) | data source |
| [acloud_cluster.cluster](https://registry.terraform.io/providers/avisi-cloud/acloud/latest/docs/data-sources/cluster) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_annotations"></a> [annotations](#input\_annotations) | Custom node annotations for nodes within the node pool | `map` | `{}` | no |
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | Default availability zone to use when the node pool is not deployed across all AZs | `string` | `""` | no |
| <a name="input_cluster_slug"></a> [cluster\_slug](#input\_cluster\_slug) | Slug of the cluster | `string` | n/a | yes |
| <a name="input_enable_auto_healing"></a> [enable\_auto\_healing](#input\_enable\_auto\_healing) | Enable node auto healing for nodes in the node pool | `bool` | `true` | no |
| <a name="input_enable_multi_availability_zones"></a> [enable\_multi\_availability\_zones](#input\_enable\_multi\_availability\_zones) | deploy the node pool in high availabilitys | `bool` | `false` | no |
| <a name="input_environment_slug"></a> [environment\_slug](#input\_environment\_slug) | A unique identifier for the environment within the organisation. Required. | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Custom node labels for nodes within the node pool | `map` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | name of the node pool | `string` | `"worker"` | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | Number of machines in the node pool | `number` | `1` | no |
| <a name="input_node_size"></a> [node\_size](#input\_node\_size) | Machine Size for nodes in the worker pool | `string` | n/a | yes |
| <a name="input_organisation_slug"></a> [organisation\_slug](#input\_organisation\_slug) | A unique identifier for the organisation. This is used to distinguish resources across different organisations. Required. | `string` | n/a | yes |

## Outputs

No outputs.

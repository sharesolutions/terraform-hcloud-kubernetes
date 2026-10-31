locals {
  # Worker Config
  worker_talos_config_patches = {
    for name, node in local.worker_servers : name => [
      {
        machine = {
          nodeLabels = merge(
            local.worker_nodepools_map[node.labels.nodepool].labels,
            { "nodeid" = tostring(node.id) }
          )
          nodeAnnotations = local.worker_nodepools_map[node.labels.nodepool].annotations
          kubelet = {
            extraConfig = merge(
              {
                registerWithTaints = local.worker_nodepools_map[node.labels.nodepool].taints
                systemReserved = {
                  cpu               = "100m"
                  memory            = "300Mi"
                  ephemeral-storage = "1Gi"
                }
                kubeReserved = {
                  cpu               = "100m"
                  memory            = "350Mi"
                  ephemeral-storage = "1Gi"
                }
              },
              var.kubernetes_kubelet_extra_config
            )
          }
        }
      },
      {
        apiVersion = "v1alpha1"
        kind       = "HostnameConfig"
        hostname   = name
        auto       = "off"
      }
    ]
  }
}

data "talos_machine_configuration" "worker" {
  for_each = toset(keys(local.worker_servers))

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  docs               = false
  examples           = false

  config_patches = concat(
    [for patch in local.talos_cloud_config_patches : yamlencode(patch)],
    var.per_node_network_config_enabled ? local.cloud_node_network_patches[each.key] : [],
    [for patch in local.worker_talos_config_patches[each.key] : yamlencode(patch)],
    contains(keys(hcloud_server.edge), each.key) && var.edge_runtime_image != null ? [
      yamlencode({ machine = { install = var.edge_runtime_image.installer == null ? { "$patch" = "delete" } : { image = var.edge_runtime_image.installer } } })
    ] : [],
    [for patch in var.worker_config_patches : yamlencode(patch)],
    [
      for patch in local.worker_nodepools_map[local.worker_servers[each.key].labels.nodepool].config_patches :
      can(tostring(patch)) ? tostring(patch) : yamlencode(patch)
    ]
  )
}

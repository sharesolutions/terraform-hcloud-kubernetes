resource "hcloud_placement_group" "control_plane" {
  count = anytrue([for np in local.control_plane_nodepools : np.placement_group]) ? 1 : 0
  name  = "${var.cluster_name}-control-plane-pg"
  type  = "spread"

  labels = {
    cluster = var.cluster_name,
    role    = "control-plane"
  }
}

resource "hcloud_placement_group" "worker" {
  for_each = merge([
    for np in local.worker_nodepools : {
      for i in range(ceil(np.count / 10.0)) : "${var.cluster_name}-${np.name}-pg-${i + 1}" => {
        nodepool = np.name
      }
    } if np.placement_group && np.count > 0
  ]...)

  name = each.key
  type = "spread"

  labels = {
    cluster  = var.cluster_name,
    nodepool = each.value.nodepool,
    role     = "worker"
  }
}

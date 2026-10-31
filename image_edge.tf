# Initial boot uses the custom disk snapshot. Publish an installer only for upgrades.
variable "edge_runtime_image" {
  type = object({
    snapshot_id = number
    installer   = optional(string)
  })
  default = null
  validation {
    condition = var.edge_runtime_image == null ? true : (
      var.edge_runtime_image.snapshot_id > 0 &&
      (var.edge_runtime_image.installer == null ? true : can(regex("^.+@sha256:[a-f0-9]{64}$", var.edge_runtime_image.installer)))
    )
    error_message = "Edge runtime requires a snapshot ID; an optional upgrade installer must be digest pinned."
  }
}

# Edges are excluded from the ordinary worker upgrade image. A changed custom
# installer digest reconciles existing machines, not just create-time user_data.
resource "terraform_data" "upgrade_edge" {
  count            = var.edge_runtime_image == null ? 0 : (var.edge_runtime_image.installer == null ? 0 : 1)
  triggers_replace = [var.talos_version, var.edge_runtime_image.installer]
  provisioner "local-exec" {
    quiet = true
    command = local.cluster_initialized ? join("\n", [
      "set -eu",
      local.talosctl_commands,
      "talos_wait_for_health",
      "for host in ${join(" ", [for name, node in hcloud_server.edge : one([for net in node.network : net.ip if net.network_id == local.hcloud_network_id])])}; do",
      "  talos_upgrade --nodes \"$host\"",
      "  talos_wait_for_health",
      "done",
    ]) : "printf '%s\\n' 'Cluster not initialized; edge runtime comes from the boot snapshot'"
    environment = {
      TALOSCONFIG         = nonsensitive(data.talos_client_configuration.this.talos_config)
      TALOS_UPGRADE_IMAGE = var.edge_runtime_image.installer
    }
  }
  depends_on = [terraform_data.upgrade_worker]
}

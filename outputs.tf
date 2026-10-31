output "talosconfig" {
  description = "Raw Talos OS configuration file used for cluster access and management."
  value       = local.talosconfig
  sensitive   = true
}

output "kubeconfig" {
  description = "Raw kubeconfig file for authenticating with the Kubernetes cluster."
  value       = local.kubeconfig
  sensitive   = true
}

output "kubeconfig_data" {
  description = "Structured kubeconfig data, suitable for use with other Terraform providers or tools."
  value       = local.kubeconfig_data
  sensitive   = true
}

output "talosconfig_data" {
  description = "Structured Talos configuration data, suitable for use with other Terraform providers or tools."
  value       = local.talosconfig_data
  sensitive   = true
}

output "talos_client_configuration" {
  description = "Detailed configuration data for the Talos client."
  value       = data.talos_client_configuration.this
  sensitive   = true
}

output "talos_machine_secrets" {
  description = "Talos machine secret, suitable for use with other Terraform providers or tools."
  value       = talos_machine_secrets.this.machine_secrets
  sensitive   = true
}

output "talos_machine_configurations_control_plane" {
  description = "Talos machine configurations for all control plane nodes."
  value       = data.talos_machine_configuration.control_plane
  sensitive   = true
}

output "talos_machine_configurations_worker" {
  description = "Talos machine configurations for all worker nodes."
  value       = data.talos_machine_configuration.worker
  sensitive   = true
}

output "control_plane_private_ipv4_list" {
  description = "List of private IPv4 addresses assigned to control plane nodes."
  value       = local.control_plane_private_ipv4_list
}

output "control_plane_public_ipv4_list" {
  description = "List of public IPv4 addresses assigned to control plane nodes."
  value       = local.control_plane_public_ipv4_list
}

output "control_plane_public_ipv6_list" {
  description = "List of public IPv6 addresses assigned to control plane nodes."
  value       = local.control_plane_public_ipv6_list
}

output "worker_private_ipv4_list" {
  description = "List of private IPv4 addresses assigned to worker nodes."
  value       = local.worker_private_ipv4_list
}

output "worker_public_ipv4_list" {
  description = "List of public IPv4 addresses assigned to worker nodes."
  value       = local.worker_public_ipv4_list
}

output "worker_public_ipv6_list" {
  description = "List of public IPv6 addresses assigned to worker nodes."
  value       = local.worker_public_ipv6_list
}

output "hcloud_vswitch_id" {
  description = "Hetzner Robot vSwitch ID used for bare metal private networking."
  value       = local.hcloud_vswitch_id
}

output "cilium_encryption_info" {
  description = "Cilium traffic encryption settings, including current state and IPsec details if enabled."
  value = {
    encryption_enabled = var.cilium_encryption_enabled
    encryption_type    = var.cilium_encryption_type

    ipsec = local.cilium_ipsec_enabled ? {
      current_key_id = var.cilium_ipsec_key_id
      next_key_id    = local.cilium_ipsec_key_config["next_id"]
      algorithm      = var.cilium_ipsec_algorithm
      key_size_bits  = var.cilium_ipsec_key_size
      secret_name    = local.cilium_ipsec_keys_manifest.metadata["name"]
      namespace      = local.cilium_ipsec_keys_manifest.metadata["namespace"]
    } : {}
  }
}

output "kube_api_load_balancer" {
  description = "Details about the Kubernetes API load balancer"
  value = var.kube_api_load_balancer_enabled ? {
    id           = hcloud_load_balancer.kube_api[0].id
    name         = local.kube_api_load_balancer_name
    public_ipv4  = local.kube_api_load_balancer_public_ipv4
    public_ipv6  = local.kube_api_load_balancer_public_ipv6
    private_ipv4 = local.kube_api_load_balancer_private_ipv4
  } : null
}

output "edge_network_attachments" {
  description = "Server attachment IDs only, independent of Kubernetes bootstrap."
  value       = { for name, node in hcloud_server.edge : name => node.network }
}

output "edge_public_ipv4_by_location" {
  description = "Actual Primary public IPv4 of each edge, keyed by location. Requires one edge per location."
  value       = { for name, node in hcloud_server.edge : node.location => node.ipv4_address }
}

output "foundation_nodes" {
  description = "Non-secret cloud node inventory for plan review."
  value = { for name, node in merge(hcloud_server.control_plane, local.worker_servers) : name => {
    location    = node.location
    server_type = node.server_type
    public_ipv4 = one(node.public_net).ipv4_enabled
    public_ipv6 = one(node.public_net).ipv6_enabled
    networks    = node.network
  } }
}

locals {
  cloud_node_pools = merge(
    { for name, node in hcloud_server.control_plane : name => local.control_plane_nodepools_map[node.labels.nodepool] },
    { for name, node in local.worker_servers : name => local.worker_nodepools_map[node.labels.nodepool] }
  )
  cloud_nodes = merge(hcloud_server.control_plane, local.worker_servers)
  cloud_node_links = {
    for name, node in local.cloud_nodes : name => merge(
      { shared = {
        mac           = one([for net in node.network : net.mac_address if net.network_id == local.hcloud_network_id])
        gateway       = local.network_ipv4_gateway
        default_route = false
      } },
      { for key, extra in local.cloud_node_pools[name].extra_networks : "egress-${key}" => {
        mac           = one([for net in node.network : net.mac_address if net.network_id == extra.network_id])
        gateway       = cidrhost(extra.cidr, 1)
        default_route = extra.default_route
      } }
    )
  }
  cloud_node_network_patches = {
    for name, node in local.cloud_nodes : name => concat(
      flatten([for alias, link in local.cloud_node_links[name] : [
        yamlencode({
          apiVersion = "v1alpha1"
          kind       = "LinkAliasConfig"
          name       = alias
          selector   = { match = "mac(link.permanent_addr) == '${link.mac}'" }
        }),
        yamlencode({
          apiVersion = "v1alpha1"
          kind       = "LinkConfig"
          name       = alias
          up         = true
          mtu        = 1450
          routes = [for route in concat(
            alias == "shared" ? local.talos_extra_routes : [],
            link.default_route ? [{ gateway = link.gateway, metric = 200 }] : []
          ) : merge(route, { metric = tonumber(route.metric) })]
        }),
        yamlencode({
          apiVersion  = "v1alpha1"
          kind        = "DHCPv4Config"
          name        = alias
          routeMetric = alias == "shared" ? 100 : 300
        })
      ]]),
      local.cloud_node_pools[name].public_ipv4_enabled ? [
        yamlencode({
          apiVersion = "v1alpha1"
          kind       = "LinkAliasConfig"
          name       = "public"
          selector = { match = join(" && ", concat(
            ["link.type == 1", "link.kind == ''"],
            [for link in values(local.cloud_node_links[name]) : "mac(link.permanent_addr) != '${link.mac}'"]
          )) }
        }),
        yamlencode({ apiVersion = "v1alpha1", kind = "DHCPv4Config", name = "public", routeMetric = 50 })
      ] : []
    )
  }
}

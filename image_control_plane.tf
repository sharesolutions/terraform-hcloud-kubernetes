# Keep administrative connectors out of worker boot assets and upgrades.
locals {
  control_plane_custom_image_enabled      = length(var.control_plane_image_extensions) > 0
  talos_control_plane_schematic_id        = local.control_plane_custom_image_enabled ? talos_image_factory_schematic.control_plane[0].id : local.talos_cloud_schematic_id
  talos_control_plane_installer_image_url = local.control_plane_custom_image_enabled ? data.talos_image_factory_urls.control_plane[0].urls.installer : local.talos_cloud_installer_image_url
  control_plane_image_selector            = "os=talos,cluster=${var.cluster_name},talos_version=${var.talos_version},talos_schematic_id=${substr(local.talos_control_plane_schematic_id, 0, 32)}"
}

resource "talos_image_factory_schematic" "control_plane" {
  count = local.control_plane_custom_image_enabled ? 1 : 0
  schematic = yamlencode({ customization = {
    extraKernelArgs  = var.talos_extra_kernel_args
    systemExtensions = { officialExtensions = distinct(concat(local.talos_cloud_image_extensions, var.control_plane_image_extensions)) }
  } })
}

data "talos_image_factory_urls" "control_plane" {
  count         = local.control_plane_custom_image_enabled ? 1 : 0
  talos_version = var.talos_version
  schematic_id  = local.talos_control_plane_schematic_id
  platform      = "hcloud"
  architecture  = "amd64"
}

data "hcloud_images" "control_plane" {
  count             = local.control_plane_custom_image_enabled ? 1 : 0
  with_selector     = local.control_plane_image_selector
  with_architecture = ["x86"]
  most_recent       = true
}

resource "terraform_data" "control_plane_image" {
  count            = local.control_plane_custom_image_enabled ? 1 : 0
  triggers_replace = [var.cluster_name, var.talos_version, local.talos_control_plane_schematic_id]
  provisioner "local-exec" {
    quiet       = true
    working_dir = "${path.module}/packer/"
    command = join(" ", [
      "${length(data.hcloud_images.control_plane[0].images) > 0} ||",
      "packer build",
      "-var 'cluster_name=${var.cluster_name}'",
      "-var 'server_type=${var.packer_amd64_builder.server_type}'",
      "-var 'server_location=${var.packer_amd64_builder.server_location}'",
      "-var 'talos_version=${var.talos_version}'",
      "-var 'talos_schematic_id=${local.talos_control_plane_schematic_id}'",
      "-var 'talos_image_url=${data.talos_image_factory_urls.control_plane[0].urls.disk_image}'",
      "image_amd64.pkr.hcl"
    ])
    environment = { HCLOUD_TOKEN = nonsensitive(var.hcloud_token) }
  }
  depends_on = [terraform_data.packer_init]
}

data "hcloud_image" "control_plane" {
  count             = local.control_plane_custom_image_enabled ? 1 : 0
  with_selector     = local.control_plane_image_selector
  with_architecture = "x86"
  most_recent       = true
  depends_on        = [terraform_data.control_plane_image]
}

resource "oci_core_instance" "jyggalag" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "jyggalag"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.bootstrap_image.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    hostname_label   = "jyggalag"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  # Boot disk gets reformatted by nixos-anywhere → ignore stock-image drift
  # so we don't recreate the instance on every plan.
  lifecycle {
    ignore_changes = [source_details, metadata]
  }
}

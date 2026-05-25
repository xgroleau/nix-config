provider "oci" {
  region              = var.region
  config_file_profile = var.oci_profile
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Oracle Linux 9 aarch64 — used as the bootstrap OS to kexec into the
# NixOS installer. Ubuntu 22.04 HWE-Oracle kernel deadlocks during kexec
# on A1.Flex; OL9 has a Red Hat-derived kernel, different code path.
# Default login user is `opc` (not `ubuntu`).
data "oci_core_images" "bootstrap_image" {
  compartment_id   = var.compartment_ocid
  operating_system = "Oracle Linux"
  shape            = "VM.Standard.A1.Flex"
  sort_by          = "TIMECREATED"
  sort_order       = "DESC"

  filter {
    name   = "display_name"
    values = ["^Oracle-Linux-9\\..*-aarch64-[0-9]"]
    regex  = true
  }
}

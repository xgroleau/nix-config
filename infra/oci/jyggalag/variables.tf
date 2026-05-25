variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID"
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID where jyggalag's resources live"
}

variable "region" {
  type        = string
  description = "OCI region (e.g. ca-toronto-1)"
}

variable "oci_profile" {
  type        = string
  description = "Profile name in ~/.oci/config"
  default     = "DEFAULT"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key authorized for bootstrap (and post-install root login until disabled)"
}

variable "ssh_private_key_path" {
  type        = string
  description = "Path to matching private key; nixos-anywhere uses it to SSH in"
  default     = "~/.ssh/id_ed25519"
}

# A1.Flex is shape-flexible. Defaults are the Always-Free maximum.
variable "ocpus" {
  type    = number
  default = 4
}

variable "memory_gbs" {
  type    = number
  default = 24
}

variable "boot_volume_gbs" {
  type    = number
  default = 200
}

# Path from the repo root to the flake. The nixos-anywhere module resolves
# `.#nixosConfigurations.jyggalag` from here.
variable "flake_root" {
  type    = string
  default = "../../.."
}

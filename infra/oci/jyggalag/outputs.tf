output "instance_id" {
  value = oci_core_instance.jyggalag.id
}

output "public_ip" {
  value = oci_core_instance.jyggalag.public_ip
}

output "private_ip" {
  value = oci_core_instance.jyggalag.private_ip
}

# Post-install user; during OL9 bootstrap (pre nixos-anywhere) use `opc`.
output "ssh_command" {
  value = "ssh root@${oci_core_instance.jyggalag.public_ip}"
}

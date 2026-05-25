output "instance_id" {
  value = oci_core_instance.jyggalag.id
}

output "public_ip" {
  value = oci_core_instance.jyggalag.public_ip
}

output "private_ip" {
  value = oci_core_instance.jyggalag.private_ip
}

output "ssh_command" {
  value = "ssh ubuntu@${oci_core_instance.jyggalag.public_ip}"
}

locals {
  quota_statements = [
    for line in split("\n", file("${path.module}/policy.txt")) :
    trimspace(line)
    if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ]
}

resource "oci_limits_quota" "free_tier_only" {
  compartment_id = var.tenancy_ocid
  name           = "jyggalag-free-tier-only"
  description    = "Default deny + allowlist matching free tier limits"
  statements     = local.quota_statements

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }
}

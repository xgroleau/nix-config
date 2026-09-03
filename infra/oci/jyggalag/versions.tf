terraform {
  required_version = ">= 1.7.0"

  required_providers {
    oci = {
      source = "oracle/oci"
      version = "9.0.0"
    }
  }

  cloud {
    organization = "xgroleau"

    workspaces {
      name = "jyggalag"
    }
  }
}

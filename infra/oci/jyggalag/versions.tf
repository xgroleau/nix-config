terraform {
  required_version = ">= 1.7.0"

  required_providers {
    oci = {
      source = "oracle/oci"
      version = "6.37.0"
    }
  }

  cloud {
    organization = "xgroleau"

    workspaces {
      name = "jyggalag"
    }
  }
}

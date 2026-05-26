terraform {
  required_version = ">= 1.7.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.0"
    }
  }

  cloud {
    organization = "xgroleau"

    workspaces {
      name = "jyggalag"
    }
  }
}

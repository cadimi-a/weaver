terraform {
  required_version = "= 1.10.3"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 2.35.1"
    }
  }
}
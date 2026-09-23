terraform {
  required_version = "1.13.5"

  cloud {
    organization = "ocp-virt-tfe-demo"

    workspaces {
      name = "test-rhel9-vm-workspace"
    }
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
  }
}

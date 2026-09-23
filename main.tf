provider "kubernetes" {
  host                   = var.host
  token                  = var.token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

locals {
  ssh_key_block        = var.ssh_public_key != "" ? "ssh_authorized_keys:\n  - ${var.ssh_public_key}\n" : ""
  cloud_init_user_data = "#cloud-config\nhostname: ${var.vm_name}\n${local.ssh_key_block}"
}

resource "kubernetes_manifest" "rhel9_vm" {
  computed_fields = [
    "metadata.annotations",
    "metadata.labels",
    "spec.template.metadata.annotations",
    "spec.template.metadata.labels",
    "spec.template.spec.domain.machine",
    "spec.template.spec.domain.firmware",
    "spec.template.spec.domain.devices.interfaces",
  ]

  manifest = {
    apiVersion = "kubevirt.io/v1"
    kind       = "VirtualMachine"
    metadata = {
      name      = var.vm_name
      namespace = var.namespace
    }
    spec = {
      running = true
      template = {
        metadata = {
          labels = {
            "kubevirt.io/vm" = var.vm_name
          }
        }
        spec = {
          domain = {
            cpu = {
              cores = var.vm_cpu_cores
            }
            devices = {
              disks = [
                {
                  name = "containerdisk"
                  disk = {
                    bus = "virtio"
                  }
                },
                {
                  name = "cloudinit"
                  disk = {
                    bus = "virtio"
                  }
                },
              ]
              interfaces = [
                {
                  name       = "default"
                  masquerade = {}
                },
              ]
            }
            resources = {
              requests = {
                memory = var.vm_memory
              }
            }
          }
          networks = [
            {
              name = "default"
              pod  = {}
            },
          ]
          volumes = [
            {
              name = "containerdisk"
              containerDisk = {
                image           = "registry.redhat.io/rhel9/rhel-guest-image:latest"
                imagePullSecret = var.rh_registry_pull_secret
              }
            },
            {
              name = "cloudinit"
              cloudInitNoCloud = {
                userData = local.cloud_init_user_data
              }
            },
          ]
        }
      }
    }
  }
}

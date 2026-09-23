# RHEL9 VM on OpenShift Virtualization — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Terraform configuration that provisions a RHEL9 VM on an OpenShift Virtualization cluster via Terraform Cloud.

**Architecture:** A flat single-directory Terraform config uses the `hashicorp/kubernetes` provider with `kubernetes_manifest` to create a `kubevirt.io/v1` `VirtualMachine` object. The VM boots from a Red Hat container disk image. All sensitive values (host, token, CA cert, pull secret name) are stored as sensitive workspace variables in Terraform Cloud and never committed to git.

**Tech Stack:** Terraform 1.13.5, `hashicorp/kubernetes` ~> 2.33, Terraform Cloud (org: `ocp-virt-tfe-demo`, workspace: `test-rhel9-vm-workspace`), OpenShift Virtualization / KubeVirt.

**Spec:** `docs/superpowers/specs/2026-09-23-rhel-vm-ocp-virt-design.md`

## Global Constraints

- Terraform version: exactly `1.13.5` (as specified in cloud block)
- Provider: `hashicorp/kubernetes` `~> 2.33`
- TFC org: `ocp-virt-tfe-demo`, workspace: `test-rhel9-vm-workspace`
- No `*.tfvars` or `*.tfvars.json` files committed to git
- The image pull Secret for `registry.redhat.io` must already exist in the target namespace — it is not managed by this config
- `cluster_ca_certificate` variable is base64-encoded (decoded via `base64decode()` in provider config)

## Review Focus

- **Empty `ssh_public_key`:** If the variable is left empty, cloud-init produces `  - ` which is invalid YAML and may prevent the VM from booting. The `cloud_init_user_data` local must conditionally omit the `ssh_authorized_keys` block when the value is empty string.
- **`masquerade = {}` empty object:** KubeVirt requires the masquerade key to be present with an empty object for pod network NAT. The `kubernetes_manifest` provider must pass `{}` without stripping it; verify the plan output shows the key present.
- **CRD schema validation:** `kubernetes_manifest` validates against the live CRD schema on `terraform plan`. If the workspace variables are not yet set, the remote plan will fail. Workspace variables must be populated before the first `terraform plan` or `terraform apply`.
- **`imagePullSecret` reference:** The value of `rh_registry_pull_secret` is the *name* of a Secret object that must already exist in `var.namespace`. If the Secret is missing or in the wrong namespace, the VMI pod will fail to pull the image.
- **`base64decode` on CA cert:** The provider expects a PEM string, not a base64-encoded string. The variable holds the base64 form; `base64decode(var.cluster_ca_certificate)` must appear in the provider block — not the raw variable.

---

## Task 1: Repository scaffolding

**Files:**
- Create: `.gitignore`
- Modify: `README.md`

**Interfaces:**
- Produces: safe repo defaults consumed by all subsequent tasks

- [ ] **Step 1: Create `.gitignore`**

```
# Local .terraform directories
**/.terraform/*

# Terraform state files — never commit these
*.tfstate
*.tfstate.*

# Crash logs
crash.log
crash.*.log

# tfvars files contain sensitive values — use TFC workspace variables instead
*.tfvars
*.tfvars.json

# Override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# CLI config files
.terraformrc
terraform.rc
```

- [ ] **Step 2: Update README.md**

Replace the contents of `README.md` with:

```markdown
# tfe-ao-demo

Provisions a RHEL9 VM on OpenShift Virtualization using Terraform Cloud.

## Prerequisites

- Terraform 1.13.5 installed locally
- Access to the `ocp-virt-tfe-demo` TFC organization
- The following workspace variables set in `test-rhel9-vm-workspace` (all sensitive unless noted):

| Variable | Sensitive | Description |
|----------|-----------|-------------|
| `host` | yes | Kubernetes API URL, e.g. `https://api.virt.na-launch.com:6443` |
| `token` | yes | Service account bearer token |
| `cluster_ca_certificate` | yes | Base64-encoded cluster CA certificate |
| `rh_registry_pull_secret` | yes | Name of the existing `registry.redhat.io` pull Secret in the target namespace |
| `ssh_public_key` | no | SSH public key to inject (leave empty to skip) |
| `namespace` | no | Target namespace (default: `default`) |
| `vm_name` | no | VM object name (default: `rhel9-vm`) |

- An image pull Secret for `registry.redhat.io` already exists in the target namespace.

## Usage

```bash
terraform login
terraform init
terraform plan   # runs remotely in TFC
terraform apply  # runs remotely in TFC
```

## Destroying the VM

```bash
terraform destroy
```
```

- [ ] **Step 3: Verify git status is clean**

```bash
git status
```

Expected: `.gitignore` and `README.md` shown as modified/new.

- [ ] **Step 4: Commit**

```bash
git add .gitignore README.md
git commit -m "chore: scaffold repo with gitignore and README"
```

---

## Task 2: Terraform cloud block and provider declaration

**Files:**
- Create: `terraform.tf`

**Interfaces:**
- Produces: `terraform` block and `required_providers` declaration consumed by all other `.tf` files

- [ ] **Step 1: Create `terraform.tf`**

```hcl
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
```

- [ ] **Step 2: Check formatting**

```bash
terraform fmt -check terraform.tf
```

Expected: no output (file is already formatted). If output appears, run `terraform fmt terraform.tf` and re-check.

- [ ] **Step 3: Commit**

```bash
git add terraform.tf
git commit -m "feat: add terraform cloud block and provider declaration"
```

---

## Task 3: Input variables

**Files:**
- Create: `variables.tf`

**Interfaces:**
- Produces: all `var.*` references used in `main.tf` and `outputs.tf`

- [ ] **Step 1: Create `variables.tf`**

```hcl
variable "host" {
  description = "Kubernetes API server URL (e.g. https://api.virt.na-launch.com:6443)"
  type        = string
  sensitive   = true
}

variable "token" {
  description = "Kubernetes service account bearer token"
  type        = string
  sensitive   = true
}

variable "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate; decoded by the provider block"
  type        = string
  sensitive   = true
}

variable "namespace" {
  description = "Namespace to create the VirtualMachine in"
  type        = string
  default     = "default"
}

variable "vm_name" {
  description = "Name of the VirtualMachine object"
  type        = string
  default     = "rhel9-vm"
}

variable "vm_cpu_cores" {
  description = "Number of vCPU cores allocated to the VM"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Memory request for the VM (e.g. 4Gi)"
  type        = string
  default     = "4Gi"
}

variable "rh_registry_pull_secret" {
  description = "Name of the existing image pull Secret for registry.redhat.io (must already exist in var.namespace)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key to inject via cloud-init (leave empty string to skip SSH key injection)"
  type        = string
  default     = ""
}
```

- [ ] **Step 2: Check formatting**

```bash
terraform fmt -check variables.tf
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add variables.tf
git commit -m "feat: add input variables"
```

---

## Task 4: Provider config, locals, and VirtualMachine resource

**Files:**
- Create: `main.tf`

**Interfaces:**
- Consumes: all `var.*` from `variables.tf`
- Produces: `kubernetes_manifest.rhel9_vm` — referenced by `outputs.tf`

- [ ] **Step 1: Create `main.tf`**

```hcl
provider "kubernetes" {
  host                   = var.host
  token                  = var.token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

locals {
  cloud_init_user_data = var.ssh_public_key != "" ? <<-EOT
    #cloud-config
    hostname: ${var.vm_name}
    ssh_authorized_keys:
      - ${var.ssh_public_key}
  EOT : <<-EOT
    #cloud-config
    hostname: ${var.vm_name}
  EOT
}

resource "kubernetes_manifest" "rhel9_vm" {
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
```

- [ ] **Step 2: Check formatting**

```bash
terraform fmt -check main.tf
```

Expected: no output. If output appears, run `terraform fmt main.tf`.

- [ ] **Step 3: Commit**

```bash
git add main.tf
git commit -m "feat: add kubernetes provider and VirtualMachine manifest"
```

---

## Task 5: Outputs

**Files:**
- Create: `outputs.tf`

**Interfaces:**
- Consumes: `kubernetes_manifest.rhel9_vm` from `main.tf`
- Produces: `vm_name`, `vm_namespace` output values displayed after apply

- [ ] **Step 1: Create `outputs.tf`**

```hcl
output "vm_name" {
  description = "Name of the created VirtualMachine object"
  value       = kubernetes_manifest.rhel9_vm.manifest.metadata.name
}

output "vm_namespace" {
  description = "Namespace the VirtualMachine was created in"
  value       = kubernetes_manifest.rhel9_vm.manifest.metadata.namespace
}
```

- [ ] **Step 2: Check formatting**

```bash
terraform fmt -check outputs.tf
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add outputs.tf
git commit -m "feat: add vm_name and vm_namespace outputs"
```

---

## Task 6: Validate and end-to-end verification

**Files:**
- No new files; validates the complete configuration

**Interfaces:**
- Consumes: all `.tf` files from Tasks 2–5

- [ ] **Step 1: Log in to Terraform Cloud**

```bash
terraform login
```

Follow the prompt to authenticate. This creates a local token at `~/.terraform.d/credentials.tfrc.json` (not committed to git).

- [ ] **Step 2: Initialize the workspace**

```bash
terraform init
```

Expected: provider `hashicorp/kubernetes ~> 2.33` downloaded, TFC workspace connected. If it fails with an authentication error, re-run `terraform login`.

- [ ] **Step 3: Validate configuration syntax**

```bash
terraform validate
```

Expected: `Success! The configuration is valid.`

If validation fails with a schema error about the `VirtualMachine` CRD (e.g., "unknown field"), it means the provider is trying to validate against the live cluster schema. Set the workspace variables in TFC first (Step 4), then retry.

- [ ] **Step 4: Set workspace variables in TFC**

In the TFC UI at `app.terraform.io`, navigate to:
`ocp-virt-tfe-demo` → `test-rhel9-vm-workspace` → `Variables`

Add the following Terraform variables (use "Add variable" → category: Terraform):

| Key | Value | Sensitive |
|-----|-------|-----------|
| `host` | `https://api.virt.na-launch.com:6443` | ✓ |
| `token` | `<service-account-token>` | ✓ |
| `cluster_ca_certificate` | `<base64-encoded-CA-cert>` | ✓ |
| `rh_registry_pull_secret` | `<pull-secret-name-in-namespace>` | ✓ |
| `ssh_public_key` | `<your-public-key>` (or leave empty) | ✗ |

To get the CA cert in base64:
```bash
oc get secret -n openshift-service-ca signing-key -o jsonpath='{.data.tls\.crt}'
# or from kubeconfig:
kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
```

To create a service account and token:
```bash
oc create serviceaccount terraform-sa -n <namespace>
oc adm policy add-cluster-role-to-user cluster-admin -z terraform-sa -n <namespace>
oc create token terraform-sa -n <namespace> --duration=8760h
```

- [ ] **Step 5: Run a remote plan**

```bash
terraform plan
```

Expected: remote plan runs in TFC, shows `Plan: 1 to add, 0 to change, 0 to destroy.` with the `kubernetes_manifest.rhel9_vm` resource. Review the plan output to confirm:
- `running = true` is present
- `masquerade = {}` is present under `interfaces`
- `containerDisk.image` is `registry.redhat.io/rhel9/rhel-guest-image:latest`
- `cloud_init_user_data` renders correctly (no bare `- ` line if SSH key was empty)

- [ ] **Step 6: Apply**

```bash
terraform apply
```

Expected: TFC runs the apply, VM is created. Outputs `vm_name` and `vm_namespace` are displayed.

Verify the VM started on the cluster:
```bash
oc get vm -n <namespace>
oc get vmi -n <namespace>
```

Expected: VM in `Running` phase, VMI exists with an IP.

- [ ] **Step 7: Final commit (if any fmt fixes were made)**

```bash
git status
# If any files were changed by terraform fmt:
git add -u
git commit -m "chore: apply terraform fmt"
```

# RHEL9 VM on OpenShift Virtualization via Terraform Cloud — Design Spec

**Date:** 2026-09-23  
**Status:** Approved

---

## Intent

Create a Terraform configuration that provisions a RHEL9 VM on an OpenShift Virtualization cluster, managed through Terraform Cloud. The repo serves as a demo of using TFC to drive VM lifecycle on OCP Virt.

## Success Criteria

- Running `terraform apply` from TFC workspace `test-rhel9-vm-workspace` creates a RHEL9 VM on the OCP Virt cluster.
- The VM boots from a Red Hat container disk image.
- Authentication uses a Kubernetes service account token + host URL + CA cert stored as sensitive TFC workspace variables.
- The configuration is readable, flat, and appropriate for a demo.

---

## Terraform Cloud Configuration

- **Organization:** `ocp-virt-tfe-demo`
- **Workspace:** `test-rhel9-vm-workspace`
- **Required Terraform version:** `1.13.5`
- **Execution mode:** Remote (runs in TFC)

---

## Provider

**`hashicorp/kubernetes`** with `kubernetes_manifest` to manage `VirtualMachine` CRDs.

Auth block uses:
```hcl
host                   = var.host
token                  = var.token
cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
```

All three are workspace variables marked sensitive in TFC.

---

## File Structure

```
/
├── terraform.tf      # cloud block, required_version, required_providers
├── variables.tf      # all input variables
├── main.tf           # provider config + kubernetes_manifest resources
└── outputs.tf        # vm_name, vm_namespace
```

---

## Variables

| Name | Type | Sensitive | Description |
|------|------|-----------|-------------|
| `host` | `string` | yes | Kubernetes API server URL (e.g. `https://api.virt.na-launch.com:6443`) |
| `token` | `string` | yes | Service account bearer token |
| `cluster_ca_certificate` | `string` | yes | Base64-encoded cluster CA certificate |
| `namespace` | `string` | no | Namespace to create the VM in (default: `default`) |
| `vm_name` | `string` | no | Name of the VirtualMachine object (default: `rhel9-vm`) |
| `vm_cpu_cores` | `number` | no | vCPU count (default: `2`) |
| `vm_memory` | `string` | no | Memory request/limit (default: `"4Gi"`) |
| `rh_registry_pull_secret` | `string` | yes | Name of the existing image pull Secret for `registry.redhat.io` (must already exist in the namespace) |
| `ssh_public_key` | `string` | no | SSH public key injected via cloud-init |

---

## Resources

### `kubernetes_manifest.rhel9_vm`

Creates a `kubevirt.io/v1` `VirtualMachine` object with:

- **`running: true`** — VM starts immediately on apply
- **Volumes:**
  - `containerDisk` — `registry.redhat.io/rhel9/rhel-guest-image:latest`, references `rh_registry_pull_secret` for pull auth
  - `cloudInitNoCloud` — injects SSH authorized key and sets hostname via `userData`
- **Devices:**
  - `disk` interface for the container disk
  - `disk` interface for the cloud-init disk
- **Resources:**
  - `requests.memory`: `var.vm_memory`
  - `cpu.cores`: `var.vm_cpu_cores`
- **Network:** `pod` network with `masquerade` interface (gives the VM a cluster-internal IP via NAT)

> **Note:** The image pull Secret (`rh_registry_pull_secret`) must already exist in the target namespace before apply. It is not managed by this Terraform config. This keeps RH credentials out of Terraform state.

### `outputs.tf`

- `vm_name` — the name of the created VM object
- `vm_namespace` — the namespace it was created in

---

## TFC Workspace Variable Setup

The following variables must be set in the TFC workspace before the first apply:

| Variable | Category | Sensitive |
|----------|----------|-----------|
| `host` | Terraform | yes |
| `token` | Terraform | yes |
| `cluster_ca_certificate` | Terraform | yes |
| `rh_registry_pull_secret` | Terraform | yes |
| `ssh_public_key` | Terraform | no |

The `namespace` and `vm_name` variables have defaults and are optional.

---

## Out of Scope

- Managing the Red Hat registry pull secret via Terraform (to avoid storing credentials in TF state)
- Persistent storage / DataVolumes (ContainerDisk is ephemeral; data does not survive pod restart)
- Exposing the VM via a Service or Route
- VM lifecycle beyond create/destroy (snapshots, live migration, etc.)

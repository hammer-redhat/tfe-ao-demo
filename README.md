# tfe-ao-demo

Provisions a RHEL9 VM on OpenShift Virtualization using Terraform Cloud.

## Prerequisites

- Terraform 1.13.5 installed locally
- Access to the `ocp-virt-tfe-demo` TFC organization
- The following **environment** variables set in `test-rhel9-vm-workspace` (cluster auth):

| Env Variable | Sensitive | Description |
|--------------|-----------|-------------|
| `KUBE_HOST` | no | Kubernetes API URL, e.g. `https://api.virt.na-launch.com:6443` |
| `KUBE_TOKEN` | yes | Service account bearer token |
| `KUBE_CLUSTER_CA_CERT_DATA` | yes | Base64-encoded cluster CA certificate |

- The following **Terraform** variables set in `test-rhel9-vm-workspace`:

| Variable | Sensitive | Description |
|----------|-----------|-------------|
| `rh_registry_pull_secret` | yes | Name of the existing `registry.redhat.io` pull Secret in the target namespace |
| `ssh_public_key` | no | SSH public key to inject (leave empty to skip) |
| `namespace` | no | Target namespace (default: `default`) |
| `vm_name` | no | VM object name (default: `rhel9-vm`) |
| `vm_cpu_cores` | no | Number of vCPU cores (default: `2`) |
| `vm_memory` | no | Memory request, e.g. `4Gi` (default: `4Gi`) |

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

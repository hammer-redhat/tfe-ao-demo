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

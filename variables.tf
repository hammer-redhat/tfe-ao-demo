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

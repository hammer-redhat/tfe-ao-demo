output "vm_name" {
  description = "Name of the created VirtualMachine object"
  value       = kubectl_manifest.rhel9_vm.name
}

output "vm_namespace" {
  description = "Namespace the VirtualMachine was created in"
  value       = kubectl_manifest.rhel9_vm.namespace
}

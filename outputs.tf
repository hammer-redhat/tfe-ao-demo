output "vm_name" {
  description = "Name of the created VirtualMachine object"
  value       = kubernetes_manifest.rhel9_vm.manifest.metadata.name
}

output "vm_namespace" {
  description = "Namespace the VirtualMachine was created in"
  value       = kubernetes_manifest.rhel9_vm.manifest.metadata.namespace
}

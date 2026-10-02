output "project_number" {
  description = "GCP Project Number"
  value       = data.google_project.project.number
}

output "service_account_email" {
  description = "Antigravity Service Account Email"
  value       = google_service_account.antigravity_sa.email
}

output "vm_name" {
  description = "GCE VM Instance Name"
  value       = google_compute_instance.ag_vm_1.name
}

output "vm_internal_ip" {
  description = "Internal VPC IP of the GCE VM instance (used as EXTERNAL_IP in Cloud Run)"
  value       = google_compute_instance.ag_vm_1.network_interface[0].network_ip
}

output "vm_external_ip" {
  description = "External IP of the GCE VM instance"
  value       = google_compute_instance.ag_vm_1.network_interface[0].access_config[0].nat_ip
}

output "vpc_connector_id" {
  description = "Serverless VPC Access Connector ID"
  value       = google_vpc_access_connector.shared_cloudrun_connector.id
}

output "cloud_run_url" {
  description = "URL of the deployed Cloud Run service (remote-browser-vm1)"
  value       = google_cloud_run_v2_service.remote_browser_vm1.uri
}

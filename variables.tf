variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "agy-remote-vm-prj"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone for GCE instance"
  type        = string
  default     = "us-central1-a"
}

variable "manage_org_policies" {
  description = "Whether to manage project-level Organization Policies (requires roles/orgpolicy.policyAdmin)"
  type        = bool
  default     = true
}

variable "vm_name" {
  description = "Name of the GCE VM instance"
  type        = string
  default     = "ag-vm-1"
}

variable "vm_machine_type" {
  description = "Machine type for the GCE VM instance"
  type        = string
  default     = "e2-standard-16"
}

variable "vm_image" {
  description = "Boot disk image for the GCE VM instance"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2604-resolute-amd64-v20260918"
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "remote-browser-vm1"
}

variable "cloud_run_image" {
  description = "Container image for the Cloud Run reverse proxy"
  type        = string
  default     = "us-docker.pkg.dev/qwiklabs-resources/lfs-images/nginx-reverse-proxy:latest"
}

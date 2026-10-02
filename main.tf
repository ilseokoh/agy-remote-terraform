# ------------------------------------------------------------------------------
# Project Metadata
# ------------------------------------------------------------------------------
data "google_project" "project" {
  project_id = var.project_id
}

# ------------------------------------------------------------------------------
# 1. API Enable
# ------------------------------------------------------------------------------
locals {
  services = [
    "compute.googleapis.com",
    "vpcaccess.googleapis.com",
    "run.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "orgpolicy.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.services)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ------------------------------------------------------------------------------
# 2. Organization Policies (Disable / Allow All)
# ------------------------------------------------------------------------------
resource "google_project_organization_policy" "require_os_login" {
  count      = var.manage_org_policies ? 1 : 0
  project    = var.project_id
  constraint = "constraints/compute.requireOsLogin"

  boolean_policy {
    enforced = false
  }

  depends_on = [google_project_service.apis]
}

resource "google_project_organization_policy" "vm_external_ip_access" {
  count      = var.manage_org_policies ? 1 : 0
  project    = var.project_id
  constraint = "constraints/compute.vmExternalIpAccess"

  list_policy {
    allow {
      all = true
    }
  }

  depends_on = [google_project_service.apis]
}

resource "google_org_policy_policy" "require_invoker_iam" {
  count  = var.manage_org_policies ? 1 : 0
  name   = "projects/${var.project_id}/policies/run.managed.requireInvokerIam"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      enforce = "FALSE"
    }
  }

  depends_on = [
    google_project_service.apis["orgpolicy.googleapis.com"]
  ]
}

# GCP Organization Policy 변경 사항이 Compute Engine / Cloud Run에 전파되기까지
# 약 30~60초가 소요되므로 대기 후 리소스를 생성합니다.
resource "terraform_data" "wait_for_org_policy_propagation" {
  count = var.manage_org_policies ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'Waiting 60s for GCP Org Policy propagation...' && sleep 60"
  }

  depends_on = [
    google_project_organization_policy.require_os_login,
    google_project_organization_policy.vm_external_ip_access,
    google_org_policy_policy.require_invoker_iam,
  ]
}

# ------------------------------------------------------------------------------
# 3. Default VPC Network
# ------------------------------------------------------------------------------
resource "google_compute_network" "default" {
  project                 = var.project_id
  name                    = "default"
  auto_create_subnetworks = true

  depends_on = [
    google_project_service.apis["compute.googleapis.com"]
  ]
}

# ------------------------------------------------------------------------------
# 4. Firewall Rules
# ------------------------------------------------------------------------------
resource "google_compute_firewall" "ag_vm_firewall" {
  project   = var.project_id
  name      = "ag-vm-firewall"
  network   = google_compute_network.default.name
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["3000", "3001"]
  }

  source_ranges = ["10.8.0.0/28"]
  target_tags   = ["ag-app"]
}

resource "google_compute_firewall" "allow_ssh_qwiklabs_tracking" {
  project   = var.project_id
  name      = "allow-ssh-qwiklabs-tracking"
  network   = google_compute_network.default.name
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ag-app"]
}

resource "google_compute_firewall" "default_allow_icmp" {
  project     = var.project_id
  name        = "default-allow-icmp"
  network     = google_compute_network.default.name
  direction   = "INGRESS"
  priority    = 65534
  description = "Allow ICMP from anywhere"

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "default_allow_internal" {
  project     = var.project_id
  name        = "default-allow-internal"
  network     = google_compute_network.default.name
  direction   = "INGRESS"
  priority    = 65534
  description = "Allow internal traffic on the default network"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.128.0.0/9"]
}

resource "google_compute_firewall" "default_allow_rdp" {
  project     = var.project_id
  name        = "default-allow-rdp"
  network     = google_compute_network.default.name
  direction   = "INGRESS"
  priority    = 65534
  description = "Allow RDP from anywhere"

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "default_allow_ssh" {
  project     = var.project_id
  name        = "default-allow-ssh"
  network     = google_compute_network.default.name
  direction   = "INGRESS"
  priority    = 65534
  description = "Allow SSH from anywhere"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# ------------------------------------------------------------------------------
# 5. Service Account & IAM Roles
# ------------------------------------------------------------------------------
resource "google_service_account" "antigravity_sa" {
  project      = var.project_id
  account_id   = "antigravity-sa"
  display_name = "Antigravity Service Account"

  depends_on = [
    google_project_service.apis["iam.googleapis.com"]
  ]
}

locals {
  sa_roles = [
    "roles/aiplatform.admin",
    "roles/aiplatform.agentContextEditor",
    "roles/aiplatform.agentDefaultAccess",
    "roles/aiplatform.expressUser",
    "roles/aiplatform.user",
    "roles/artifactregistry.admin",
    "roles/artifactregistry.reader",
    "roles/cloudbuild.admin",
    "roles/cloudbuild.builds.editor",
    "roles/cloudscheduler.admin",
    "roles/compute.admin",
    "roles/discoveryengine.admin",
    "roles/iam.serviceAccountUser",
    "roles/logging.admin",
    "roles/logging.viewer",
    "roles/modelarmor.admin",
    "roles/pubsub.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/run.admin",
    "roles/run.developer",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/serviceusage.serviceUsageConsumer",
    "roles/storage.admin",
  ]
}

resource "google_project_iam_member" "antigravity_sa_roles" {
  for_each = toset(local.sa_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.antigravity_sa.email}"
}

# ------------------------------------------------------------------------------
# 6. GCE VM Instance (ag-vm-1)
# ------------------------------------------------------------------------------
resource "google_compute_instance" "ag_vm_1" {
  project      = var.project_id
  name         = var.vm_name
  zone         = var.zone
  machine_type = var.vm_machine_type
  tags         = ["ag-app"]

  boot_disk {
    device_name = "persistent-disk-0"
    initialize_params {
      image = var.vm_image
      size  = 100
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.default.id
    subnetwork = "default"

    access_config {
      network_tier = "PREMIUM"
    }
  }

  service_account {
    email  = google_service_account.antigravity_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    block-project-ssh-keys = "FALSE"
    enable-oslogin         = "FALSE"
    startup-script         = file("${path.module}/startup-script.sh")
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  labels = {
    goog-terraform-provisioned = "true"
  }

  depends_on = [
    google_project_organization_policy.require_os_login,
    google_project_organization_policy.vm_external_ip_access,
    terraform_data.wait_for_org_policy_propagation,
    google_project_iam_member.antigravity_sa_roles,
  ]
}

# ------------------------------------------------------------------------------
# 7. Serverless VPC Access Connector
# ------------------------------------------------------------------------------
resource "google_vpc_access_connector" "shared_cloudrun_connector" {
  project       = var.project_id
  name          = "shared-cloudrun-connector"
  region        = var.region
  network       = google_compute_network.default.name
  ip_cidr_range = "10.8.0.0/28"
  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 5

  depends_on = [
    google_project_service.apis["vpcaccess.googleapis.com"],
    google_compute_network.default,
  ]
}

# ------------------------------------------------------------------------------
# 8. Cloud Run Service (remote-browser-vm1)
# ------------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "remote_browser_vm1" {
  project  = var.project_id
  name     = var.cloud_run_service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account                  = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"
    timeout                          = "300s"
    max_instance_request_concurrency = 2

    scaling {
      min_instance_count = 1
      max_instance_count = 2
    }

    vpc_access {
      connector = google_vpc_access_connector.shared_cloudrun_connector.id
      egress    = "ALL_TRAFFIC"
    }

    containers {
      image = var.cloud_run_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name  = "BACKEND_PORT"
        value = "3000"
      }
      env {
        name  = "FRONTEND_PORT"
        value = "8080"
      }
      env {
        name  = "EXTERNAL_IP"
        value = google_compute_instance.ag_vm_1.network_interface[0].network_ip
      }

      startup_probe {
        tcp_socket {
          port = 8080
        }
        period_seconds    = 240
        timeout_seconds   = 240
        failure_threshold = 1
      }
    }
  }

  depends_on = [
    google_project_service.apis["run.googleapis.com"],
    google_org_policy_policy.require_invoker_iam,
    terraform_data.wait_for_org_policy_propagation,
  ]
}

# Allow unauthenticated invocations (--allow-unauthenticated)
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = google_cloud_run_v2_service.remote_browser_vm1.project
  location = google_cloud_run_v2_service.remote_browser_vm1.location
  name     = google_cloud_run_v2_service.remote_browser_vm1.name
  role     = "roles/run.invoker"
  member   = "allUsers"

  depends_on = [
    google_org_policy_policy.require_invoker_iam,
    terraform_data.wait_for_org_policy_propagation,
  ]
}

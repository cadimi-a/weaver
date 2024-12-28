/***********************************************************************************************************************
 $                                                       Network                                                       $
 **********************************************************************************************************************/
locals {
  primary_subnet_ip_cidr_range    = "10.0.0.0/16"
  k8s_pod_ip_cidr_range           = "10.1.0.0/16"
  k8s_svc_ip_cidr_range           = "10.2.0.0/20"
  k8s_control_plane_ip_cidr_range = "172.16.0.0/28"
}

resource "google_compute_network" "vpc_network" {
  name                    = var.infra_name_tag
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "primary_subnet" {
  name                     = "${var.infra_name_tag}-primary-subnet"
  network                  = google_compute_network.vpc_network.self_link
  region                   = var.region
  ip_cidr_range            = local.primary_subnet_ip_cidr_range
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pod-range"
    ip_cidr_range = local.k8s_pod_ip_cidr_range
  }

  secondary_ip_range {
    range_name    = "service-range"
    ip_cidr_range = local.k8s_svc_ip_cidr_range
  }

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.infra_name_tag}-allow-ssh"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 100

  source_ranges = [var.developer_ip, "35.235.240.0/20"] # GCP IAP IP range
  allow {
    protocol = "tcp"
    ports = ["22"]
  }
}

resource "google_compute_firewall" "allow_lb_health_check" {
  name    = "${var.infra_name_tag}-allow-lb-health-check"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 200

  source_ranges = [
    "35.191.0.0/16", # GCP Load Balancer health check IP range
    "130.211.0.0/22"  # GCP Load Balancer health check IP range
  ]

  allow {
    protocol = "tcp"
    ports = ["80", "443"]
  }
}

resource "google_compute_firewall" "allow_http_https" {
  name    = "${var.infra_name_tag}-allow-http-https"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 300

  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports = ["80", "443"]
  }
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.infra_name_tag}-allow-internal"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 400

  source_ranges = [
    local.primary_subnet_ip_cidr_range,
    local.k8s_pod_ip_cidr_range,
    local.k8s_svc_ip_cidr_range,
    local.k8s_control_plane_ip_cidr_range
  ]
  allow {
    protocol = "all"
  }
}

resource "google_compute_router" "nat_router" {
  name                          = var.infra_name_tag
  network                       = google_compute_network.vpc_network.name
  encrypted_interconnect_router = true
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.infra_name_tag}-nat"
  router                             = google_compute_router.nat_router.name
  region                             = google_compute_router.nat_router.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.primary_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  nat_ips = [google_compute_address.nat.self_link]
}

resource "google_compute_address" "nat" {
  name         = "${var.infra_name_tag}-nat"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

/***********************************************************************************************************************
 $                                                     GKE Cluster                                                     $
 **********************************************************************************************************************/
resource "google_container_cluster" "gke_cluster" {
  name     = var.infra_name_tag
  location = var.region

  network    = google_compute_network.vpc_network.self_link
  subnetwork = google_compute_subnetwork.primary_subnet.self_link

  deletion_protection      = false
  remove_default_node_pool = true
  initial_node_count       = 1

  monitoring_service = "monitoring.googleapis.com/kubernetes"
  logging_service    = "logging.googleapis.com/kubernetes"

  release_channel {
    channel = "STABLE"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.primary_subnet.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.primary_subnet.secondary_ip_range[1].range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = local.k8s_control_plane_ip_cidr_range
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = local.primary_subnet_ip_cidr_range
      display_name = "Primary Subnet Access"
    }
  }
}

resource "google_service_account" "gke_node_pool_sa" {
  account_id   = "${var.infra_name_tag}-gke-node-pool"
  display_name = "${var.infra_name_tag}-gke-node-pool-service-account"
}

resource "google_project_iam_member" "gke_node_binding_nsa" {
  project = var.project_id
  role    = "roles/container.nodeServiceAccount"
  member = "serviceAccount:${google_service_account.gke_node_pool_sa.email}"
}
resource "google_project_iam_member" "gke_node_binding_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node_pool_sa.email}"
}

resource "google_project_iam_member" "gke_node_binding_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node_pool_sa.email}"
}

resource "google_project_iam_member" "gke_node_binding_monitor_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_node_pool_sa.email}"
}

resource "google_container_node_pool" "primary_node_pool" {
  name           = var.infra_name_tag
  cluster        = google_container_cluster.gke_cluster.id
  location       = google_container_cluster.gke_cluster.location
  node_locations = var.zones

  initial_node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 1
  }

  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = 50
    service_account = google_service_account.gke_node_pool_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  depends_on = [
    google_container_cluster.gke_cluster
  ]
}

/***********************************************************************************************************************
 $                                                       Compute                                                       $
 **********************************************************************************************************************/

# TBU

/***********************************************************************************************************************
 $                                                     Persistence                                                     $
 **********************************************************************************************************************/

# TBU

data "google_client_config" "default" {}
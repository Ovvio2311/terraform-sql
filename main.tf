data "google_client_config" "default" {
}

provider "google" {
  credentials = file("/mnt/c/Users/jackyli/Downloads/able-scope-413414-d1f3a6012760.json")

  project = "able-scope-413414"
  region  = "us-central1"
  zone    = "us-central1-c"
}
provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}
provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    client_certificate     = base64decode(module.gke.ca_certificate)
    # client_key             = base64decode(google_container_cluster.primary.master_auth.0.client_key)
    # cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  }
}

module "gcp-network" {
  source  = "terraform-google-modules/network/google"
  version = ">= 7.5"

  project_id   = var.project_id
  network_name = var.network

  subnets = [
    {
      subnet_name           = var.subnetwork
      subnet_ip             = "10.0.0.0/24"
      subnet_region         = var.region
      subnet_private_access = "false"
    },
  ]

  secondary_ranges = {
    (var.subnetwork) = [
      {
        range_name    = var.ip_range_pods_name
        ip_cidr_range = "172.20.0.0/20"
      },
      {
        range_name    = var.ip_range_services_name
        ip_cidr_range = "172.18.0.0/18"
      },
    ]
  }
}

data "google_compute_subnetwork" "subnetwork" {
  name       = var.subnetwork
  project    = var.project_id
  region     = var.region
  depends_on = [module.gcp-network]
}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "~> 30.0"

  project_id = var.project_id
  name       = var.cluster_name
  regional   = false
  region     = var.region
  zones      = slice(var.zones, 0, 1)

  network                 = module.gcp-network.network_name
  subnetwork              = module.gcp-network.subnets_names[0]
  ip_range_pods           = var.ip_range_pods_name
  ip_range_services       = var.ip_range_services_name
  create_service_account  = false
  http_load_balancing     = false
  enable_private_endpoint = true
  enable_private_nodes    = true
  master_ipv4_cidr_block  = "10.0.1.0/28"
  deletion_protection     = false
  remove_default_node_pool= true
  network_policy          = true
  # master_version          = "1.29.1-gke.1425000"
  kubernetes_version      = "1.29"
  release_channel         = "UNSPECIFIED"
  fleet_project           = "able-scope-413414"
  disable_legacy_metadata_endpoints = true
  master_authorized_networks = [
    {
      cidr_block   = data.google_compute_subnetwork.subnetwork.ip_cidr_range
      display_name = "VPC"
    },
  ]

  node_pools = [
    {
      name               = "fyp-node-pool"
      machine_type       = "e2-medium"
      image_type         = "UBUNTU_CONTAINERD"
      node_version       = "1.29"
      min_count          = 1
      max_count          = 1
      disk_size_gb       = 100
      disk_type          = "pd-balanced"
      auto_repair        = true
      auto_upgrade       = false
      preemptible        = false
      initial_node_count = 1
    },
  ]

  

  node_pools_labels = {

    all = {

    }
    my-node-pool = {

    }
  }

  node_pools_metadata = {
    all = {}

    my-node-pool = {}

  }

  node_pools_tags = {
    all = []

    my-node-pool = []

  }
}
module "firewall_rules" {
  source       = "terraform-google-modules/network/google//modules/firewall-rules"
  project_id   = var.project_id
  network_name = var.network
  depends_on = [module.gcp-network]
  rules = [
    {
      name                    = "allow-ingress"
      description             = null
      direction               = "INGRESS"
      priority                = null
      destination_ranges      = ["0.0.0.0/0"]
      source_ranges           = ["0.0.0.0/0"]
      source_tags             = null
      source_service_accounts = null
      target_tags             = null
      target_service_accounts = null
      allow = [{
        protocol = "tcp"
        ports    = ["22","5050","3389","30443","2224","9443"]
      }]
      deny = []
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name                    = "allow-http"
      description             = null
      direction               = "INGRESS"
      priority                = null
      destination_ranges      = ["0.0.0.0/0"]
      source_ranges           = ["0.0.0.0/0"]
      source_tags             = null
      source_service_accounts = null
      target_tags             = null
      target_service_accounts = null
      allow = [{
      protocol = "tcp"
      ports    = ["80","443"]
    }]
  }]
}

resource "google_compute_router" "router" {
  name    = "fyp-router"
  region  = data.google_compute_subnetwork.subnetwork.region
  network = data.google_compute_subnetwork.subnetwork.name
  depends_on = [module.gcp-network]
  bgp {
    asn = 64514
  }
}
resource "google_compute_router_nat" "nat" {
  name                               = "fyp-router-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  depends_on                         = [module.gcp-network]
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
resource "google_compute_address" "static" {
  name         = "nginx-controller"
  address_type = "EXTERNAL"
  purpose      = "GCE_ENDPOINT"
}

resource "helm_release" "nginx_ingress_controller" {
  name       = "ingress-nginx"
  namespace  = "ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  values     = ["${file("values.yaml")}"]
  create_namespace = true
  # ip_address = google_compute_address.static.address
  depends_on = [module.gke]
  loadBalancerIP = {
    name = google_compute_address.static.name
    value = google_compute_address.static.address
  }
}

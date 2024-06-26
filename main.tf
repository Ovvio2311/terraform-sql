
data "google_client_config" "default" {  
}

/*data "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = "us-central1-c"
  
}*/

provider "google" {
  # credentials = file("/mnt/c/Users/jackyli/Downloads/able-scope-413414-d1f3a6012760.json")
  project = var.project_id
  region  = "us-central1"
  zone    = "us-central1-c"
}

/*
provider "helm" {
  kubernetes {
    # config_path = "~/.kube/config"
    # host                   = "https://${module.gke.endpoint}"
    host  = "https://${data.google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    # cluster_ca_certificate   = base64decode(module.gke.ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["container", "clusters", "get-credentials", var.cluster_name, "--zone", "us-central1", "--project", var.project_id]
      # args=[]
      # command="gke-gloud-auth-plugin"
      command     = "gcloud"
    }
    cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
    client_key             = base64decode(data.google_container_cluster.primary.master_auth.0.client_key)
    client_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.client_certificate)
  }
}*/
# ----------------------------------------------------------------------------------------
/*resource "google_compute_global_address" "private_ip_address" { 

  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = "projects/able-scope-413414/global/networks/default"
}
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = "projects/able-scope-413414/global/networks/default"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}*/

resource "random_id" "db_name_suffix" {
  byte_length = 4
}
resource "random_id" "name" {
  byte_length = 2
}

module "mysql-db" {
  source  = "terraform-google-modules/sql-db/google//modules/mysql"
  version = "~> 18.0"  
 # depends_on = [google_service_networking_connection.private_vpc_connection]
  name                 = var.db_name
  random_instance_name = true
  database_version     = "MYSQL_8_0"
  project_id           = var.project_id
  zone                 = "us-central1-c"
  region               = "us-central1"
  tier                 = "db-n1-standard-1"
  edition              = "ENTERPRISE"
  root_password        = "3Dp1&MBZ"
  deletion_protection  = false
  availability_type    = "ZONAL"
  disk_type            = "PD_SSD"

  ip_configuration = {
    ipv4_enabled        = true
    # private_network     = "projects/able-scope-413414/global/networks/default"
    require_ssl         = false
    # allocated_ip_range  = "google-managed-services-fyp"
    authorized_networks = var.authorized_networks
    # enable_private_path_for_google_cloud_services = true
  }


  database_flags = [
    {
      name  = "log_bin_trust_function_creators"
      value = "on"
    },
  ]
}


data "google_client_config" "default" {  
}
data "google_client_config" "update" {
  depends_on = [module.gke]
}
data "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = "us-central1-c"
  # depends_on = [module.gke]
}
data "google_container_cluster" "update" {
  name     = var.cluster_name
  location = "us-central1-c"
  depends_on = [module.gke]
}
provider "google" {
  # credentials = file("/mnt/c/Users/jackyli/Downloads/able-scope-413414-d1f3a6012760.json")
  project = "able-scope-413414"
  region  = "us-central1"
  zone    = "us-central1-c"
}
provider "kubernetes" {
  host  = "https://${data.google_container_cluster.primary.endpoint}"  
  token                  = data.google_client_config.default.access_token    
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  # client_key             = base64decode(data.google_container_cluster.primary.master_auth.0.client_key)
  # client_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.client_certificate)
}

provider "helm" {
  kubernetes {
    # config_path = "~/.kube/config"
    # host                   = "https://${module.gke.endpoint}"
    host  = "https://${data.google_container_cluster.update.endpoint}"
    token                  = data.google_client_config.update.access_token
    # cluster_ca_certificate   = base64decode(module.gke.ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["container", "clusters", "get-credentials", var.cluster_name, "--zone", "us-central1", "--project", var.project_id]
      # args=[]
      # command="gke-gloud-auth-plugin"
      command     = "gcloud"
    }
    cluster_ca_certificate = base64decode(data.google_container_cluster.update.master_auth[0].cluster_ca_certificate)
    client_key             = base64decode(data.google_container_cluster.update.master_auth.0.client_key)
    client_certificate = base64decode(data.google_container_cluster.update.master_auth.0.client_certificate)
  }
}
# ----------------------------------------------------------------------------------------
resource "random_id" "name" {
  byte_length = 2
}

module "mysql-db" {
  source  = "terraform-google-modules/sql-db/google//modules/mysql"
  version = "~> 18.0"

  name                 = var.db_name
  random_instance_name = true
  database_version     = "MYSQL_5_6"
  project_id           = var.project_id
  zone                 = "us-central1-c"
  region               = "us-central1"
  tier                 = "db-n1-standard-1"

  deletion_protection = false

  ip_configuration = {
    ipv4_enabled        = true
    private_network     = null
    require_ssl         = true
    allocated_ip_range  = null
    authorized_networks = var.authorized_networks
  }


  database_flags = [
    {
      name  = "log_bin_trust_function_creators"
      value = "on"
    },
  ]
}

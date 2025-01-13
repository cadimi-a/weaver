provider "kubernetes" {
  host                   = data.terraform_remote_state.cluster.outputs.kubeconfig["host"]
  token                  = data.terraform_remote_state.cluster.outputs.kubeconfig["token"]
  cluster_ca_certificate = data.terraform_remote_state.cluster.outputs.kubeconfig["cluster_ca_certificate"]
}

data "terraform_remote_state" "cluster" {
  backend = "local"
  config = {
    path = "../infra/terraform.tfstate"
  }
}

# provider "kubernetes" {
#   config_path    = "~/.kube/config"
#   config_context = "minikube"
# }
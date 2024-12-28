variable "workloads_name_tag" {
  type = string
}

variable "app_deployment_map" {
  type = map(object({
    key = string
    path = string
    image = string
    replicas = number
    container_port = number
  }))

  default = {
    api = {
      key = "api"
      path = "/api"
      image = "nginx:latest"
      replicas = 1
      container_port = 80
    }
    web = {
      key = "web"
      path = "/"
      image = "nginx:latest"
      replicas = 1
      container_port = 80
    }
    data = {
      key = "data"
      path = "/data"
      image = "nginx:latest"
      replicas = 1
      container_port = 80
    }
  }
}

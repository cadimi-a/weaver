resource "kubernetes_namespace" "ingress" {
  metadata {
    name = "${var.workloads_name_tag}-ingress"
  }
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = "${var.workloads_name_tag}-app"
  }
}

/***********************************************************************************************************************
 $                                                        Auth                                                         $
 **********************************************************************************************************************/
resource "kubernetes_service_account" "nginx_ingress" {
  metadata {
    name      = "${var.workloads_name_tag}-ingress-sa"
    namespace = kubernetes_namespace.ingress.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "nginx_ingress" {
  metadata {
    name = "${var.workloads_name_tag}-ingress"
  }

  rule {
    api_groups = [""]
    resources = ["configmaps", "endpoints", "nodes", "pods", "secrets", "services"]
    verbs = ["list", "watch", "get"]
  }

  rule {
    api_groups = ["discovery.k8s.io"]
    resources = ["endpointslices"]
    verbs = ["list", "watch"]
  }

  rule {
    api_groups = ["coordination.k8s.io"]
    resources = ["leases"]
    verbs = ["get", "watch", "list", "create", "update"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources = ["ingressclasses", "ingresses", "ingresses/status"]
    verbs = ["get", "list", "watch", "update"]
  }

  rule {
    api_groups = [""]
    resources = ["events"]
    verbs = ["create", "patch"]
  }
}

resource "kubernetes_cluster_role_binding" "nginx_ingress" {
  metadata {
    name = "${var.workloads_name_tag}-nginx-ingress"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.nginx_ingress.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.nginx_ingress.metadata[0].name
    namespace = kubernetes_namespace.ingress.metadata[0].name
  }
}

/***********************************************************************************************************************
 $                                                       Ingress                                                       $
 **********************************************************************************************************************/
resource "kubernetes_ingress_class" "nginx_ingress" {
  metadata {
    name = "${var.workloads_name_tag}-ingress-class"
  }

  spec {
    controller = "k8s.io/ingress-nginx"
  }
}

resource "kubernetes_deployment" "ingress_controller" {
  depends_on = [kubernetes_service.app_services]

  metadata {
    name      = "${var.workloads_name_tag}-ingress-controller"
    namespace = kubernetes_namespace.ingress.metadata[0].name
    labels = {
      app = "${var.workloads_name_tag}-ingress-controller"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "${var.workloads_name_tag}-ingress"
      }
    }

    template {
      metadata {
        labels = {
          app = "${var.workloads_name_tag}-ingress"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.nginx_ingress.metadata[0].name

        container {
          name  = "nginx-ingress-controller"
          image = "registry.k8s.io/ingress-nginx/controller:v1.11.3"

          args = [
            "/nginx-ingress-controller",
            "--election-id=ingress-controller-leader",
            "--controller-class=k8s.io/ingress-nginx",
            "--ingress-class=nginx",
            "--configmap=$(POD_NAMESPACE)/${var.workloads_name_tag}-nginx-config-map"
          ]

          port {
            container_port = 80
            name           = "http"
          }

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 10254
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 10254
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
        }
      }
    }
  }
}
resource "kubernetes_config_map" "nginx_config_map" {
  metadata {
    name      = "${var.workloads_name_tag}-nginx-config-map"
    namespace = kubernetes_namespace.ingress.metadata[0].name
  }
}

resource "kubernetes_service" "ingress_controller_service" {
  depends_on = [kubernetes_deployment.ingress_controller]
  metadata {
    name      = "${var.workloads_name_tag}-ingress-service"
    namespace = kubernetes_namespace.ingress.metadata[0].name
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = kubernetes_deployment.ingress_controller.spec[0].selector[0].match_labels.app
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    port {
      name        = "https"
      port        = 443
      target_port = 443
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_ingress_v1" "app_ingress" {
  metadata {
    name      = "${var.workloads_name_tag}-app-ingress"
    namespace = kubernetes_namespace.ingress.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    rule {
      http {
        dynamic "path" {
          for_each = var.app_deployment_map
          content {
            path      = path.value.path
            path_type = "Prefix"
            backend {
              service {
                name = path.key
                port {
                  number = path.value.container_port
                }
              }
            }
          }
        }
      }
    }
  }
}

/***********************************************************************************************************************
 $                                                         App                                                         $
 **********************************************************************************************************************/
resource "kubernetes_service" "app_services" {
  for_each = var.app_deployment_map
  depends_on = [kubernetes_deployment.app_deployment]

  metadata {
    name = each.key
  }

  spec {
    selector = {
      app = each.key
    }

    port {
      name        = each.key
      port        = each.value.container_port
      target_port = each.value.container_port
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "app_deployment" {
  for_each = var.app_deployment_map

  metadata {
    name      = each.key
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    replicas = each.value.replicas

    selector {
      match_labels = {
        app = each.key
      }
    }

    template {
      metadata {
        labels = {
          app = each.key
        }
      }

      spec {
        container {
          name  = each.key
          image = each.value.image

          port {
            container_port = each.value.container_port
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "api_hpa" {
  metadata {
    name      = "${var.workloads_name_tag}-${var.app_deployment_map.api["key"]}-hpa"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = var.app_deployment_map.api["key"]
    }

    min_replicas = 1
    max_replicas = 3

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}
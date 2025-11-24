# Namespace
resource "kubernetes_namespace" "employee_api" {
  metadata {
    name = var.namespace
    labels = {
      name        = var.namespace
      environment = "production"
      managed-by  = "terraform"
    }
  }
}

# Persistent Volume Claim
resource "kubernetes_persistent_volume_claim" "employee_api_data" {
  metadata {
    name      = "${var.app_name}-data"
    namespace = kubernetes_namespace.employee_api.metadata[0].name
    labels = {
      app = var.app_name
    }
  }
  
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.storage_size
      }
    }
    storage_class_name = "standard-rwo"
  }
  
  wait_until_bound = false
}

# Deployment
resource "kubernetes_deployment" "employee_api" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.employee_api.metadata[0].name
    labels = {
      app     = var.app_name
      version = "v1"
    }
  }
  
  spec {
    replicas = var.min_replicas
    
    selector {
      match_labels = {
        app = var.app_name
      }
    }
    
    template {
      metadata {
        labels = {
          app     = var.app_name
          version = "v1"
        }
      }
      
      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          fs_group        = 1000
        }
        
        container {
          name  = var.app_name
          image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.app_name}/${var.app_name}:${var.image_tag}"
          image_pull_policy = "Always"
          
          port {
            container_port = 8080
            name           = "http"
            protocol       = "TCP"
          }
          
          env {
            name  = "DATABASE_PATH"
            value = "/app/data/employees.db"
          }
          
          env {
            name  = "PORT"
            value = "8080"
          }
          
          env {
            name  = "LOG_LEVEL"
            value = "INFO"
          }
          
          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
          
          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
          
          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 3
            failure_threshold     = 3
          }
          
          volume_mount {
            name       = "data"
            mount_path = "/app/data"
          }
          
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
            capabilities {
              drop = ["ALL"]
            }
          }
        }
        
        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.employee_api_data.metadata[0].name
          }
        }
        
        restart_policy = "Always"
      }
    }
  }
}

# Service
resource "kubernetes_service" "employee_api" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.employee_api.metadata[0].name
    labels = {
      app = var.app_name
    }
  }
  
  spec {
    type = "ClusterIP"
    
    selector = {
      app = var.app_name
    }
    
    port {
      name        = "http"
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }
    
    session_affinity = "None"
  }
}

# Ingress
resource "kubernetes_ingress_v1" "employee_api" {
  metadata {
    name      = "${var.app_name}-ingress"
    namespace = kubernetes_namespace.employee_api.metadata[0].name
    labels = {
      app = var.app_name
    }
    annotations = {
      "kubernetes.io/ingress.class"                = "nginx"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
      "nginx.ingress.kubernetes.io/ssl-redirect"   = "false"
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = "false"
    }
  }
  
  spec {
    ingress_class_name = "nginx"
    
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          
          backend {
            service {
              name = kubernetes_service.employee_api.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

# Horizontal Pod Autoscaler
resource "kubernetes_horizontal_pod_autoscaler_v2" "employee_api" {
  metadata {
    name      = "${var.app_name}-hpa"
    namespace = kubernetes_namespace.employee_api.metadata[0].name
    labels = {
      app = var.app_name
    }
  }
  
  spec {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
    
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.employee_api.metadata[0].name
    }
    
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
    
    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
    
    behavior {
      scale_down {
        stabilization_window_seconds = 300
        policy {
          type           = "Percent"
          value          = 50
          period_seconds = 60
        }
      }
      
      scale_up {
        stabilization_window_seconds = 0
        select_policy                = "Max"
        
        policy {
          type           = "Percent"
          value          = 100
          period_seconds = 30
        }
        
        policy {
          type           = "Pods"
          value          = 2
          period_seconds = 30
        }
      }
    }
  }
}

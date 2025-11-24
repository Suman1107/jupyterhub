output "artifact_registry_repository" {
  description = "Artifact Registry repository URL"
  value       = google_artifact_registry_repository.employee_api.name
}

output "artifact_registry_url" {
  description = "Full Artifact Registry URL for images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.app_name}"
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = kubernetes_namespace.employee_api.metadata[0].name
}

output "service_name" {
  description = "Kubernetes service name"
  value       = kubernetes_service.employee_api.metadata[0].name
}

output "ingress_name" {
  description = "Kubernetes ingress name"
  value       = kubernetes_ingress_v1.employee_api.metadata[0].name
}

# Commented out since Cloud Build trigger is optional
# output "cloudbuild_trigger_id" {
#   description = "Cloud Build trigger ID"
#   value       = google_cloudbuild_trigger.employee_api_build.id
# }

output "deployment_command" {
  description = "Command to get ingress IP"
  value       = "kubectl get ingress -n ${var.namespace} ${var.app_name}-ingress"
}

output "image_url" {
  description = "Full Docker image URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.app_name}/${var.app_name}:${var.image_tag}"
}

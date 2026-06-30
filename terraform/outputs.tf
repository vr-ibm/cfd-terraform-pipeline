# outputs.tf - output value definitions

output "container_registry_path" {
	description = "Base path for pushing container images"
	value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.cfd.repository_id}"
}

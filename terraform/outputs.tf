# outputs.tf - output value definitions

output "container_registry_path" {
  description = "Base path for pushing container images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.cfd.repository_id}"
}

output "bigquery_dataset" {
  description = "BigQuery dataset ID for CFD results"
  value       = google_bigquery_dataset.cfd_results.dataset_id
}

output "bigquery_runs_table" {
  description = "Fully qualified BigQuery table ID for run results"
  value       = "${google_bigquery_dataset.cfd_results.project}:${google_bigquery_dataset.cfd_results.dataset_id}.${google_bigquery_table.runs.table_id}"
}

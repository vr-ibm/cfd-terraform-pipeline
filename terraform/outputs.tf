output "results_bucket" {
  value = google_storage_bucket.cfd_results.name
}

output "bigquery_table" {
  value = "${google_bigquery_dataset.cfd.dataset_id}.${google_bigquery_table.coefficients.table_id}"
}

output "service_account_email" {
  value = google_service_account.batch_runner.email
}

output "cloud_run_job" {
  value = google_cloud_run_v2_job.cfd_sweep.name
}

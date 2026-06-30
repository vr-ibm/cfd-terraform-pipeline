resource "google_bigquery_dataset" "cfd" {
  project    = var.project_id
  dataset_id = "cfd_results"
  location   = var.region
}

resource "google_bigquery_table" "coefficients" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.cfd.dataset_id
  table_id   = "coefficients"

  schema = jsonencode([
    { name = "case_name", type = "STRING", mode = "REQUIRED" },
    { name = "airfoil", type = "STRING", mode = "REQUIRED" },
    { name = "aoa", type = "FLOAT", mode = "REQUIRED" },
    { name = "reynolds", type = "FLOAT", mode = "REQUIRED" },
    { name = "mach", type = "FLOAT", mode = "REQUIRED" },
    { name = "cl", type = "FLOAT", mode = "REQUIRED" },
    { name = "cd", type = "FLOAT", mode = "REQUIRED" },
    { name = "cm", type = "FLOAT", mode = "REQUIRED" },
    { name = "iterations", type = "INTEGER", mode = "NULLABLE" },
    { name = "wall_time_seconds", type = "INTEGER", mode = "NULLABLE" },
    { name = "converged", type = "BOOLEAN", mode = "NULLABLE" },
    { name = "timestamp", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "machine_type", type = "STRING", mode = "NULLABLE" },
  ])
}

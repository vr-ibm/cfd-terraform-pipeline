# bigquery.tf - BigQuery resources

resource "google_bigquery_dataset" "cfd_results" {
  dataset_id                 = "cfd_results"
  friendly_name              = "CFD Simulation Results"
  description                = "Stores results and metadata from CFD pipeline runs"
  location                   = var.region
  delete_contents_on_destroy = true

  depends_on = [google_project_service.required["bigquery.googleapis.com"]]
}

resource "google_bigquery_table" "runs" {
  dataset_id          = google_bigquery_dataset.cfd_results.dataset_id
  table_id            = "runs"
  deletion_protection = false
  description         = "Individual CFD simulation run results"

  schema = jsonencode([
    {
      name        = "run_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique identifier for the run"
    },
    {
      name        = "timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "When the run completed"
    },
    {
      name        = "airfoil"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Airfoil profile name"
    },
    {
      name        = "case_name"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Full case identifier"
    },
    {
      name        = "aoa"
      type        = "FLOAT"
      mode        = "REQUIRED"
      description = "Angle of attack in degrees"
    },
    {
      name        = "reynolds"
      type        = "FLOAT"
      mode        = "REQUIRED"
      description = "Reynolds number"
    },
    {
      name        = "mach"
      type        = "FLOAT"
      mode        = "REQUIRED"
      description = "Mach number"
    },
    {
      name        = "cl"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Lift coefficient"
    },
    {
      name        = "cd"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Drag coefficient"
    },
    {
      name        = "cm"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Moment coefficient"
    },
    {
      name        = "iterations"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Number of solver iterations"
    },
    {
      name        = "wall_time_seconds"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Total wall clock time in seconds"
    },
    {
      name        = "cost_usd"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Estimated compute cost in USD"
    },
    {
      name        = "machine_type"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "GCP machine type used"
    },
    {
      name        = "converged"
      type        = "BOOLEAN"
      mode        = "NULLABLE"
      description = "Whether the solver converged"
    },
  ])
}

resource "google_bigquery_table" "residuals" {
  dataset_id          = google_bigquery_dataset.cfd_results.dataset_id
  table_id            = "residuals"
  deletion_protection = false
  description         = "Solver residual history per iteration"

  schema = jsonencode([
    {
      name = "run_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "iteration"
      type = "INTEGER"
      mode = "REQUIRED"
    },
    {
      name        = "p_residual"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Pressure residual"
    },
    {
      name        = "ux_residual"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Velocity X residual"
    },
    {
      name        = "uy_residual"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Velocity Y residual"
    },
    {
      name        = "uz_residual"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Velocity Z residual"
    },
    {
      name        = "nuTilda_residual"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Turbulence residual"
    },
  ])
}

resource "google_project_iam_member" "batch_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.batch_runner.email}"
}

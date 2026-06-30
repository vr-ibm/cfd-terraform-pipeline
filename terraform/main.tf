# main.tf - core infrastructure orchestration

locals {
  required_apis = [
    "batch.googleapis.com",
    "compute.googleapis.com",
    "storage.googleapis.com",
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
  ]

  batch_runner_roles = [
    "roles/batch.agentReporter",
    "roles/storage.objectAdmin",
    "roles/bigquery.dataEditor",
    "roles/logging.logWriter",
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "batch_runner" {
  project      = var.project_id
  account_id   = "cfd-batch-runner"
  display_name = "CFD Batch Runner Service Account"
}

resource "google_project_iam_member" "batch_runner_roles" {
  for_each = toset(local.batch_runner_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.batch_runner.email}"
}

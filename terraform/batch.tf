resource "google_cloud_run_v2_job" "cfd_sweep" {
  name     = "cfd-sweep"
  location = var.region
  project  = var.project_id

  template {
    parallelism = 7
    task_count  = 7

    template {
      service_account = google_service_account.batch_runner.email

      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.cfd.repository_id}/openfoam-cfd:latest"

        env {
          name  = "AIRFOIL"
          value = "naca0012"
        }
        env {
          name  = "REYNOLDS"
          value = "3000000"
        }
        env {
          name  = "MACH"
          value = "0.15"
        }
        env {
          name  = "GCS_BUCKET"
          value = google_storage_bucket.cfd_results.name
        }

        resources {
          limits = {
            cpu    = "4"
            memory = "8Gi"
          }
        }
      }

      timeout = "600s"
    }
  }

  depends_on = [google_project_service.required]
}

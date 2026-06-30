# NOTE: google_cloud_batch_job requires google provider >= 5.44.0
# This file is excluded from validation when using local provider overrides.
# Uncomment and use when deploying with the published provider.

/*
# batch.tf - Cloud Batch resources

resource "google_cloud_batch_job" "cfd_run" {
  for_each = { for c in var.cases : c.name => c }

  name     = each.value.name
  location = var.region
  project  = var.project_id

  task_groups {
    task_count = 1

    task_spec {
      compute_resource {
        cpu_milli  = 16000
        memory_mib = 32768
      }

      max_retry_count  = 1
      max_run_duration = "3600s"

      runnables {
        container {
          image_uri  = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.cfd.repository_id}/openfoam-cfd:${var.container_image_tag}"
          entrypoint = "/opt/cfd/entrypoint.sh"
        }

        environment {
          variables = {
            CASE_NAME         = each.value.name
            AIRFOIL           = each.value.airfoil
            AOA               = tostring(each.value.aoa)
            REYNOLDS          = tostring(each.value.reynolds)
            MACH              = tostring(each.value.mach)
            GCS_INPUT_BUCKET  = google_storage_bucket.input.name
            GCS_OUTPUT_BUCKET = google_storage_bucket.output.name
            MACHINE_TYPE      = var.machine_type
          }
        }
      }
    }
  }

  allocation_policy {
    instances {
      policy {
        machine_type       = var.machine_type
        provisioning_model = "STANDARD"
      }
    }

    network {
      network_interfaces {
        network                = google_compute_network.cfd_hpc.id
        subnetwork             = google_compute_subnetwork.cfd_hpc.id
        no_external_ip_address = true
      }
    }

    service_account {
      email  = google_service_account.batch_runner.email
      scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    }

    location {
      allowed_locations = ["zones/${var.zone}"]
    }
  }

  logs_policy {
    destination = "CLOUD_LOGGING"
  }

  labels = {
    project = "cfd-pipeline"
    case    = each.value.name
    airfoil = each.value.airfoil
  }

  depends_on = [
    google_project_service.required["batch.googleapis.com"],
    google_artifact_registry_repository_iam_member.batch_pull,
    google_storage_bucket_iam_member.batch_input_read,
    google_storage_bucket_iam_member.batch_output_write,
  ]
}

*/

# storage.tf - storage resources

resource "google_storage_bucket" "input" {
	name                        = "${var.project_id}-cfd-input"
	location                    = var.region
	force_destroy               = true
	uniform_bucket_level_access = true
	storage_class               = "STANDARD"

	depends_on = [google_project_service.required["storage.googleapis.com"]]
}

resource "google_storage_bucket" "output" {
	name                        = "${var.project_id}-cfd-output"
	location                    = var.region
	force_destroy               = true
	uniform_bucket_level_access = true
	storage_class               = "STANDARD"

	depends_on = [google_project_service.required["storage.googleapis.com"]]

	lifecycle_rule {
		action {
			type = "Delete"
		}

		condition {
			age = 7
		}
	}
}

resource "google_storage_bucket_iam_member" "batch_input_read" {
	bucket = google_storage_bucket.input.name
	role   = "roles/storage.objectViewer"
	member = "serviceAccount:${google_service_account.batch_runner.email}"
}

resource "google_storage_bucket_iam_member" "batch_output_write" {
	bucket = google_storage_bucket.output.name
	role   = "roles/storage.objectAdmin"
	member = "serviceAccount:${google_service_account.batch_runner.email}"
}

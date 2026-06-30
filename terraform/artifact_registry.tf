# artifact_registry.tf - Artifact Registry resources

resource "google_artifact_registry_repository" "cfd" {
	location      = var.region
	repository_id = "cfd-openfoam"
	description   = "Docker repository for OpenFOAM CFD containers"
	format        = "DOCKER"

	depends_on = [google_project_service.required["artifactregistry.googleapis.com"]]
}

resource "google_artifact_registry_repository_iam_member" "batch_pull" {
	location   = google_artifact_registry_repository.cfd.location
	repository = google_artifact_registry_repository.cfd.name
	role       = "roles/artifactregistry.reader"
	member     = "serviceAccount:${google_service_account.batch_runner.email}"
}

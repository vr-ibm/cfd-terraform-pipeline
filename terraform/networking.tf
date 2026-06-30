# networking.tf - networking resources

resource "google_compute_network" "cfd_hpc" {
  name                    = "cfd-hpc-network"
  auto_create_subnetworks = false
  project                 = var.project_id

  depends_on = [google_project_service.required["compute.googleapis.com"]]
}

resource "google_compute_subnetwork" "cfd_hpc" {
  name                     = "cfd-hpc-subnet"
  ip_cidr_range            = "10.0.0.0/24"
  region                   = var.region
  network                  = google_compute_network.cfd_hpc.id
  private_ip_google_access = true
}

resource "google_compute_router" "cfd_router" {
  name    = "cfd-hpc-router"
  region  = var.region
  network = google_compute_network.cfd_hpc.id
}

resource "google_compute_router_nat" "cfd_nat" {
  name                               = "cfd-hpc-nat"
  router                             = google_compute_router.cfd_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "cfd_internal" {
  name          = "cfd-allow-internal"
  network       = google_compute_network.cfd_hpc.id
  direction     = "INGRESS"
  source_ranges = ["10.0.0.0/24"]
  description   = "Allow all internal traffic between HPC nodes"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }
}

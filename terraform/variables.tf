# variables.tf - input variable definitions

variable "project_id" {
  description = "GCP project ID to deploy into"
  type        = string
  default     = null
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for compute resources"
  type        = string
  default     = "us-central1-a"
}

variable "cases" {
  description = "List of CFD simulation cases to run"
  type = list(object({
    name     = string
    airfoil  = string
    aoa      = number
    reynolds = number
    mach     = number
  }))
  default = [
    { name = "naca0012_aoa0", airfoil = "naca0012", aoa = 0, reynolds = 3000000, mach = 0.15 },
    { name = "naca0012_aoa2", airfoil = "naca0012", aoa = 2, reynolds = 3000000, mach = 0.15 },
    { name = "naca0012_aoa4", airfoil = "naca0012", aoa = 4, reynolds = 3000000, mach = 0.15 },
    { name = "naca0012_aoa6", airfoil = "naca0012", aoa = 6, reynolds = 3000000, mach = 0.15 },
    { name = "naca0012_aoa8", airfoil = "naca0012", aoa = 8, reynolds = 3000000, mach = 0.15 },
    { name = "naca0012_aoa10", airfoil = "naca0012", aoa = 10, reynolds = 3000000, mach = 0.15 },
    { name = "naca0012_aoa12", airfoil = "naca0012", aoa = 12, reynolds = 3000000, mach = 0.15 },
  ]
}

variable "machine_type" {
  description = "GCP machine type for Batch compute VMs"
  type        = string
  default     = "c3-highcpu-22"
}

variable "container_image_tag" {
  description = "Tag for the OpenFOAM container image"
  type        = string
  default     = "latest"
}

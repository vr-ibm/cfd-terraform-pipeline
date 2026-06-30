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

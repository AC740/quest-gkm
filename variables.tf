variable "gcp_project_id" {
  type        = string
  description = "The GCP project ID to deploy resources into."
  default     = "ac-2025-8-15"
}

variable "gcp_region" {
  type        = string
  description = "The GCP region for the resources."
  default     = "us-central1"
}
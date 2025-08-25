terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# 1. Enable necessary APIs
resource "google_project_service" "gke_api" {
  service = "container.googleapis.com"
}
resource "google_project_service" "artifactregistry_api" {
  service = "artifactregistry.googleapis.com"
}

# 2. Artifact Registry to store the Docker image
resource "google_artifact_registry_repository" "app_repo" {
  location      = var.gcp_region
  repository_id = "cloud-quest-gke-repo"
  format        = "DOCKER"
  depends_on    = [google_project_service.artifactregistry_api]
}

# 3. GKE Autopilot Cluster
resource "google_container_cluster" "primary" {
  name             = "cloud-quest-cluster"
  location         = var.gcp_region
  enable_autopilot = true
  
  depends_on = [google_project_service.gke_api]
}
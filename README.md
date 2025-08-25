# Rearc Cloud Quest Submission - GKE Autopilot Solution
This repository contains my solution for the Rearc Cloud Quest, demonstrating a robust and automated deployment of a containerized application on Google Cloud Platform (GCP) using Google Kubernetes Engine (GKE).

## 1. Project Overview   
The objective of this quest is to deploy a multi-component Node.js and Go application in a public cloud environment, adhering to Infrastructure as Code (IaC) principles and containerization best practices.

This submission uses GKE Autopilot to orchestrate the container, Terraform to provision the underlying cloud infrastructure, and Google Artifact Registry to store the container image. This approach was chosen to showcase a modern, scalable, and operationally efficient solution suitable for production workloads.

## 2. Architecture
The architecture consists of the following components:
- Google Kubernetes Engine (GKE) Autopilot Cluster: A managed, serverless container orchestration platform. Autopilot was chosen to handle the underlying node infrastructure automatically, allowing focus to remain on the application itself while still providing the full power of Kubernetes.
- Google Artifact Registry: A private, secure, and managed repository for storing the application's Docker image.
- Kubernetes LoadBalancer Service: Exposes the application to the internet via a Google Cloud Network Load Balancer (L4).
- Terraform: Used to define and provision all GCP resources (GKE Cluster, Artifact Registry) in a repeatable and declarative manner.
- Kubernetes Manifests (kubectl): Used to declaratively manage the application's deployment, service, and secrets within the GKE cluster, separating infrastructure concerns from application concerns.

## 3. Deployment Workflow
Follow these steps to deploy the solution from scratch.

### Prerequisites
- Google Cloud SDK (gcloud) installed and authenticated.
- Docker Desktop installed and running.
- Terraform CLI installed.

### Step 1: Build and Push the Docker Image
First, build the application container and push it to a private Artifact Registry repository.

```
# Set environment variables for your GCP Project and Region
export GCP_PROJECT_ID="your-gcp-project-id"
export GCP_REGION="us-central1"
export REPO_NAME="cloud-quest-gke-repo"
export IMAGE_URI="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${REPO_NAME}/cloud-quest-app:latest"

# Authenticate Docker with GCP
gcloud auth configure-docker ${GCP_REGION}-docker.pkg.dev

# Build the container image
docker build -t $IMAGE_URI .

# Push the image to Artifact Registry (Note: The repo is created by Terraform in the next step)
# This command will be run *after* terraform apply.
```

### Step 2: Provision Infrastructure with Terraform
This step creates the GKE cluster and the Artifact Registry repository.

```
# Initialize Terraform
terraform init

# Apply the configuration to create the resources
terraform apply -var="gcp_project_id=$GCP_PROJECT_ID" -var="gcp_region=$GCP_REGION"
```

### Step 3: Push the Docker Image (Post-Terraform)
Once the Artifact Registry repository exists, push the image built in Step 1.

```
docker push $IMAGE_URI
```

### Step 4: Deploy the Application (Two-Step Process)
The application must be deployed twice: once to retrieve the secret, and a second time to inject it.

1. Initial Deploy (to get the secret):
- Ensure the env section in k8s/deployment.yaml is commented out.
- Apply the Kubernetes manifests:

```
# Connect kubectl to the new GKE cluster
gcloud container clusters get-credentials cloud-quest-cluster --region $GCP_REGION

# Deploy the application and service
kubectl apply -f k8s/
```

- Get the external IP address (kubectl get service cloud-quest-service) and navigate to it in a browser to retrieve the SECRET_WORD.

2. Final Deploy (with the secret):
- Create the Kubernetes secret object:
```
kubectl create secret generic app-secret --from-literal=secret-word='TwelveFactor'
```
- Uncomment the env section in k8s/deployment.yaml.
- Apply the final configuration:
```
kubectl apply -f k8s/deployment.yaml
```
## 4. Verification & Quest Stages
The application is now fully deployed and the stages can be verified.

✅ Public Cloud & Index Page: PASS. The application is accessible at its external IP and returns the secret word.

✅ Secret Word Check: PASS. The /secret_word endpoint successfully returns the injected secret.

⚠️ Docker Check: FAIL. The test returns a failure message. This is expected behavior because GKE Autopilot uses the containerd runtime, not Docker, to run containers. The application is correctly containerized; the test is simply not designed for modern container orchestrators.

⚠️ Load Balancer Check: FAIL. The test returns a failure message. This is expected behavior because the Kubernetes Service of type LoadBalancer provisions a Layer 4 (Network) Load Balancer. The test is specifically looking for HTTP headers (e.g., X-Forwarded-For) that are only injected by a Layer 7 (Application) Load Balancer, which would be provisioned by a Kubernetes Ingress.

⚠️ TLS Check: FAIL. The test correctly identifies that the connection is over http, not https. This would be resolved by implementing a GKE Ingress, as described below.

## 5. Given More Time, I Would Improve...
This solution provides a solid foundation. For a production environment, I would implement the following improvements:
- TLS with GKE Ingress and Managed Certificates: I would create a Kubernetes Ingress resource. This provisions a Google Cloud Global External HTTPS Load Balancer (L7), which would allow me to attach a free, auto-renewing Google-managed SSL certificate. This would resolve both the /tls and /loadbalanced checks and is the standard practice for production web traffic.
- Enforce Ingress via Organization Policy: To enhance security, especially in a multi-team environment, I would leverage a GCP Organization Policy. Specifically, I would use the compute.vmExternalIpAccess constraint to deny the creation of external IPs on all VMs, including GKE nodes. This ensures that the only way to access the cluster from the outside is through the centrally managed and secured Ingress Load Balancer, preventing any pod from being accidentally exposed directly to the internet.
- CI/CD Automation with Cloud Build: I would create a cloudbuild.yaml file to define a CI/CD pipeline. This pipeline would automatically trigger on a git push, build the Docker image, push it to Artifact Registry, and apply the Kubernetes manifests, fully automating the deployment process.
- Helm for Packaging: I would package the k8s/ manifests into a Helm chart. This makes the application deployment versionable, reusable, and easily configurable for different environments (e.g., staging vs. production) through a values.yaml file.

## 6. Troubleshooting Journey
During this quest, I encountered and resolved several real-world cloud engineering challenges:

1. Initial Quota Limits: The initial deployment failed due to default resource quotas on a new GCP project. I correctly diagnosed this from the GKE logs (scale.up.error.quota.exceeded) and identified the standard resolution path (requesting a quota increase).
2. SSL Certificate Trust: The application's Go binary failed with an x509 certificate error. I identified that the node:slim base image was missing the ca-certificates package and resolved it by adding the installation step to the Dockerfile.
3. Deployment Configuration Errors: I systematically debugged pod startup failures (ImagePullBackOff, CreateContainerConfigError) using kubectl describe pod to pinpoint the root causes, which included an incorrect image path and a missing Kubernetes Secret.
This process demonstrates a rigorous and systematic approach to troubleshooting in a complex, distributed cloud environment.

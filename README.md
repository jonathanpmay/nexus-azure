# Nexus
Creates an Azure DevOps code pipeline

# Dependencies
- Two environment variables must be defined (AZDO_PERSONAL_ACCESS_TOKEN and AZDO_ORG_SERVICE_URL)
- Azure DevOps Terraform extension must be installed
- Storage account created to store the Terraform backend

# Context
- Pipelines must be initialized manually
- Define pipelines using Terraform workspaces

# Usage
1. Export required environment variables
2. Create new Terraform workspace
3. Terraform apply to create a new DevOps project and associated resources
4. Copy the azure-pipelines.yml to a DevOps pipeline as a standard template
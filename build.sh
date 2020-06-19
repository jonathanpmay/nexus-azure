#!/bin/bash

# Exit if any commmand fails
set -e

# Initialize Terraform
terraform init

# Validate syntax
terraform validate

# Fix formatting
terraform fmt -recursive .

# Terraform plan and apply
terraform plan -out out.tfplan
terraform apply out.tfplan
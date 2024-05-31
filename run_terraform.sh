#!/bin/bash

# Prompt the user for AWS credentials
read -p "Enter your AWS Access Key ID: " AWS_ACCESS_KEY_ID
read -sp "Enter your AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo

# Export AWS credentials as environment variables
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY

# Check if variable file argument is passed
if [ -z "$1" ]; then
  echo "Usage: $0 <path_to_tfvars_file>"
  exit 1
fi

# Store the path to the variables file
VARS_FILE=$1

# Initialize Terraform
terraform init

# Plan Terraform deployment
terraform plan -var-file="$VARS_FILE"

# Apply Terraform deployment
terraform apply -var-file="$VARS_FILE"
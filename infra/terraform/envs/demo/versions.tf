terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.70" }
  }
  # Bucket comes from backend.hcl (see backend.hcl.example); use_lockfile = native S3 locking, no DynamoDB.
  backend "s3" {}
}

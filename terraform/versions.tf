terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local state (solo project, applied from the laptop with fresh Learner Lab creds).
  # For teamwork: switch to an S3 backend + DynamoDB lock.
}

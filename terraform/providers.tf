provider "aws" {
  region = var.region

  # Tags applied to every supported resource for traceability inside the lab.
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}

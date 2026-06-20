# ---------------------------------------------------------------------------
# ECR repositories for the frontend and backend images.
# Images are built in CI (or from the laptop) and pushed here; Ansible pulls
# them onto the EC2 instances at deploy time.
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "this" {
  for_each = toset(["frontend", "backend"])

  name                 = "${var.project}/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # allow `terraform destroy` even with images present

  image_scanning_configuration {
    scan_on_push = true # free vulnerability scan on push
  }

  tags = { Name = "${var.project}-ecr-${each.key}" }
}

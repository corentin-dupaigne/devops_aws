# ---------------------------------------------------------------------------
# Static EC2 instances (frontend, backend) in public subnets.
# They reuse the existing LabInstanceProfile (the lab forbids creating roles),
# which grants ECR pull, SSM Parameter Store read and CloudWatch access.
# Configuration (Docker, image pull, run, secrets) is handled by Ansible.
# ---------------------------------------------------------------------------

# Latest Amazon Linux 2023 AMI (x86_64).
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Validate the pre-existing instance profile exists in the lab account.
data "aws_iam_instance_profile" "lab" {
  name = var.instance_profile_name
}

resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.frontend_security_group_id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab.name
  key_name               = var.key_name

  tags = {
    Name = "${var.project}-frontend"
    Tier = "frontend"
  }
}

resource "aws_instance" "backend" {
  # Spread to the second AZ for a bit of resilience.
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_ids[1]
  vpc_security_group_ids = [var.backend_security_group_id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab.name
  key_name               = var.key_name

  tags = {
    Name = "${var.project}-backend"
    Tier = "backend"
  }
}

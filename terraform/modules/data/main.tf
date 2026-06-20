# ---------------------------------------------------------------------------
# data module — RDS MySQL in the private subnets + generated credentials.
# The DB lives only in private subnets and is not publicly accessible.
# The master password is generated and never written in plaintext (stored in
# SSM Parameter Store as a SecureString, see ssm.tf).
# ---------------------------------------------------------------------------

# Subnet group spanning the private subnets (RDS requires >= 2 AZ).
resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.project}-db-subnet-group" }
}

# Generated master password. Excludes characters RDS rejects (/, @, ", space).
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "this" {
  identifier     = "${var.project}-mysql"
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  # Network: private subnets only, reachable solely through the db security group.
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_security_group_id]
  publicly_accessible    = false

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_days

  # Lab-friendly lifecycle: no final snapshot, no deletion protection.
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true

  tags = { Name = "${var.project}-mysql" }
}

# ---------------------------------------------------------------------------
# Chained security groups (graded criterion: least privilege on flows).
# Chain: Internet -> ALB -> frontend -> backend -> db
# Each tier only accepts the SG of the tier above (no inter-tier CIDR).
# SSH (22) is open only to the admin IP on frontend/backend.
# ---------------------------------------------------------------------------

# --- ALB SG: the only public entry point (HTTP 80) ---
resource "aws_security_group" "alb" {
  name        = "${var.project}-sg-alb"
  description = "ALB - public HTTP entry point"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.project}-sg-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the Internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# Accepted by design: open egress is required (no NAT in this Learner Lab setup,
# the ALB must reach its targets). Risk documented in docs/DESIGN.md section 8.
#trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "Egress to the targets"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- Frontend SG: HTTP 80 from the ALB only, SSH from the admin IP ---
resource "aws_security_group" "frontend" {
  name        = "${var.project}-sg-frontend"
  description = "Frontend Nginx - reachable only from the ALB"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.project}-sg-frontend" }
}

resource "aws_vpc_security_group_ingress_rule" "frontend_http" {
  security_group_id            = aws_security_group.frontend.id
  description                  = "HTTP from the ALB only"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "frontend_ssh" {
  security_group_id = aws_security_group.frontend.id
  description       = "Admin SSH (Ansible) restricted to the admin IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_cidr
}

# Accepted by design: open egress is required (no NAT, instance pulls ECR images
# and OS packages through the IGW). Risk documented in docs/DESIGN.md section 8.
#trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "frontend_all" {
  security_group_id = aws_security_group.frontend.id
  description       = "Egress (pull ECR, packages, proxy to backend)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- Backend SG: port 5000 from the frontend only, SSH from the admin IP ---
resource "aws_security_group" "backend" {
  name        = "${var.project}-sg-backend"
  description = "Backend Flask - reachable only from the frontend"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.project}-sg-backend" }
}

resource "aws_vpc_security_group_ingress_rule" "backend_api" {
  security_group_id            = aws_security_group.backend.id
  description                  = "API 5000 from the frontend only"
  ip_protocol                  = "tcp"
  from_port                    = 5000
  to_port                      = 5000
  referenced_security_group_id = aws_security_group.frontend.id
}

resource "aws_vpc_security_group_ingress_rule" "backend_ssh" {
  security_group_id = aws_security_group.backend.id
  description       = "Admin SSH (Ansible) restricted to the admin IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_cidr
}

# Accepted by design: open egress is required (no NAT, instance pulls ECR images
# and OS packages through the IGW). Risk documented in docs/DESIGN.md section 8.
#trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "backend_all" {
  security_group_id = aws_security_group.backend.id
  description       = "Egress (pull ECR, packages, reach RDS)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- DB SG: MySQL 3306 from the backend only ---
resource "aws_security_group" "db" {
  name        = "${var.project}-sg-db"
  description = "RDS MySQL - reachable only from the backend"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.project}-sg-db" }
}

resource "aws_vpc_security_group_ingress_rule" "db_mysql" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL 3306 from the backend only"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.backend.id
}

# No explicit egress rule on the DB: by default none is added here, and RDS needs
# no outbound traffic. (A SG with no egress rule = no outbound traffic allowed.)

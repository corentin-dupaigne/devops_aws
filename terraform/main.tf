# Root entry point. Infrastructure is split into modules and stacked sprint by
# sprint: Sprint 1 = network, then data / compute / observability.

module "network" {
  source = "./modules/network"

  project    = var.project
  vpc_cidr   = var.vpc_cidr
  az_count   = var.az_count
  admin_cidr = var.admin_cidr
}

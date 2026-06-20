# Root entry point. Infrastructure is split into modules and stacked sprint by
# sprint: Sprint 1 = network, then data / compute / observability.

module "network" {
  source = "./modules/network"

  project    = var.project
  vpc_cidr   = var.vpc_cidr
  az_count   = var.az_count
  admin_cidr = var.admin_cidr
}

module "data" {
  source = "./modules/data"

  project              = var.project
  private_subnet_ids   = module.network.private_subnet_ids
  db_security_group_id = module.network.security_group_ids.db
  multi_az             = var.db_multi_az
}

module "compute" {
  source = "./modules/compute"

  project                    = var.project
  vpc_id                     = module.network.vpc_id
  public_subnet_ids          = module.network.public_subnet_ids
  alb_security_group_id      = module.network.security_group_ids.alb
  frontend_security_group_id = module.network.security_group_ids.frontend
  backend_security_group_id  = module.network.security_group_ids.backend
  instance_type              = var.instance_type
  key_name                   = var.key_name
}

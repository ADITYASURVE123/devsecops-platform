provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "devsecops-platform", ManagedBy = "terraform" }
  }
}

data "aws_availability_zones" "available" { state = "available" }

locals {
  azs   = slice(data.aws_availability_zones.available.names, 0, 2)
  repos = ["orders-api", "inventory-api"]
}

module "vpc" {
  source = "../../modules/vpc"
  name   = var.name
  azs    = local.azs
}

module "ecr" {
  source       = "../../modules/ecr"
  repositories = local.repos
}

module "jenkins" {
  source              = "../../modules/jenkins"
  name                = var.name
  vpc_id              = module.vpc.vpc_id
  subnet_id           = module.vpc.public_subnets[0]
  allowed_cidr        = var.my_ip_cidr
  instance_type       = var.jenkins_instance_type
  ecr_repository_arns = module.ecr.repository_arns
}

module "eks" {
  source             = "../../modules/eks"
  cluster_name       = "${var.name}-eks"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  node_instance_type = var.node_instance_type
  api_allowed_cidrs  = [var.my_ip_cidr]
}

# Cost guard: email at 80% actual and 100% forecast.
resource "aws_budgets_budget" "monthly" {
  name         = "${var.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}

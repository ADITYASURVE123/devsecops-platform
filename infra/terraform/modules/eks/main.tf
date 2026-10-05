variable "cluster_name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "node_instance_type" {
  type    = string
  default = "c7i-flex.large"
}
variable "api_allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public Kubernetes API (your IP /32)"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = "1.34"
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true
  cluster_endpoint_public_access_cidrs     = var.api_allowed_cidrs

  cluster_addons = {
    vpc-cni = {
      most_recent          = true
      configuration_values = jsonencode({ enableNetworkPolicy = "true" }) # enforce NetworkPolicy
    }
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND" # cheaper; fine for a demo
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }
  }
}

# IRSA: External Secrets Operator may read only /devsecops/* in SSM, via a pod-level role.
module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name                           = "${var.cluster_name}-external-secrets"
  attach_external_secrets_policy      = true
  external_secrets_ssm_parameter_arns = ["arn:aws:ssm:*:*:parameter/devsecops/*"]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
}

output "cluster_name" { value = module.eks.cluster_name }
output "external_secrets_role_arn" { value = module.external_secrets_irsa.iam_role_arn }

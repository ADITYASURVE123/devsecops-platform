output "cluster_name" { value = module.eks.cluster_name }
output "ecr_repository_urls" { value = module.ecr.repository_urls }
output "jenkins_instance_id" { value = module.jenkins.instance_id }
output "jenkins_public_ip" { value = module.jenkins.public_ip }
output "jenkins_private_ip" { value = module.jenkins.private_ip }
output "external_secrets_role_arn" { value = module.eks.external_secrets_role_arn }

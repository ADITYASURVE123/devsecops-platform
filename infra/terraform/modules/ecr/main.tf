variable "repositories" { type = list(string) }

resource "aws_ecr_repository" "this" {
  for_each             = toset(var.repositories)
  name                 = each.key
  image_tag_mutability = "IMMUTABLE" # a tag always means the same bytes
  force_delete         = true        # lets `terraform destroy` work in a demo account

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 10 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
      action       = { type = "expire" }
    }]
  })
}

output "repository_urls" { value = { for k, r in aws_ecr_repository.this : k => r.repository_url } }
output "repository_arns" { value = [for r in aws_ecr_repository.this : r.arn] }

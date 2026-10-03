variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "allowed_cidr" {
  type        = string
  description = "Your IP as x.x.x.x/32. No default on purpose: never open Jenkins to the world."
}
variable "instance_type" {
  type    = string
  default = "t3.small" # Jenkins + Docker is too heavy for a t3.micro
}
variable "ecr_repository_arns" { type = list(string) }

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "jenkins" {
  name_prefix = "${var.name}-jenkins-"
  vpc_id      = var.vpc_id
  description = "Jenkins UI from one trusted IP; no SSH (use SSM Session Manager)"

  ingress {
    description = "Jenkins UI + GitHub webhooks via your own tunnel/proxy"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }
  egress {
    description = "outbound to GitHub, ECR, package mirrors"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name_prefix        = "${var.name}-jenkins-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Least privilege: login + push to OUR repositories only.
data "aws_iam_policy_document" "ecr_push" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:DescribeImages",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push"
  role   = aws_iam_role.jenkins.id
  policy = data.aws_iam_policy_document.ecr_push.json
}

resource "aws_iam_instance_profile" "jenkins" {
  name_prefix = "${var.name}-jenkins-"
  role        = aws_iam_role.jenkins.name
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name
  user_data              = file("${path.module}/user_data.sh")

  associate_public_ip_address = true

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2          # lets containers reach the instance profile
  }
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }
  tags = { Name = "${var.name}-jenkins" }
}

output "instance_id" { value = aws_instance.jenkins.id }
output "public_ip" { value = aws_instance.jenkins.public_ip }
output "private_ip" { value = aws_instance.jenkins.private_ip }

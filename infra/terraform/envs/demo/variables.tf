variable "region" {
  type    = string
  default = "us-east-1"
}
variable "name" {
  type    = string
  default = "devsecops"
}
variable "my_ip_cidr" {
  type        = string
  description = "Your public IP as x.x.x.x/32 (Jenkins UI + EKS API allow-list)"
}
variable "budget_usd" {
  type    = number
  default = 10
}
variable "budget_email" {
  type        = string
  description = "Where the budget alert goes"
}
variable "jenkins_instance_type" {
  type    = string
  default = "t3.small"
}
variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

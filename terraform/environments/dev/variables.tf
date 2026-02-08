# ─────────────────────────────────────────────
# 환경 변수 (terraform.tfvars에서 주입)
# ─────────────────────────────────────────────
variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "domain_name" {
  type    = string
  default = "playbuilder.xyz"
}

variable "app_port" {
  type    = number
  default = 3000
}

variable "eks_cluster_version" {
  type    = string
  default = "1.34"
}

variable "allowed_cidrs" {
  type = list(string)
}
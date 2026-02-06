

variable "project_name" {
  description = "프로젝트 이름 (리소스 이름 prefix로 사용)"
  type        = string
  default     = "exchange-settlement"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "프로젝트 이름은 소문자, 숫자, 하이픈만 허용됩니다."
  }
}

variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be either 'dev' or 'prod'."
  }
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Main domain name (Managed by Cloudflare)"
  type        = string
  default     = "playbuilder.xyz"
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 3000
}

variable "eks_cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.34"
}

locals {
  project_name = "exchange-settlement"
  cluster_name = "${local.project_name}-${var.environment}"

  vpc_config = {
    dev = {
      cidr            = "10.0.0.0/16"
      private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
      public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
    }
    prod = {
      cidr            = "10.1.0.0/16"
      private_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
      public_subnets  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
    }
  }

  node_config = {
    dev = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 3
      capacity_type  = "SPOT"
    }
    prod = {
      instance_types = ["t3.large", "t3a.large", "m5.large"]
      desired_size   = 2
      min_size       = 2
      max_size       = 5
      capacity_type  = "ON_DEMAND"
    }
  }

  env_config = {
    dev = {
      single_nat_gateway  = true
      deletion_protection = false
      ingress_replicas    = 1
    }
    prod = {
      single_nat_gateway  = false
      deletion_protection = true
      ingress_replicas    = 2
    }
  }

  common_tags = {
    Project     = local.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
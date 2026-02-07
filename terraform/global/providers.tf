# =============================================================================
# 🌐 Global Layer - Providers
# =============================================================================
# 환경(dev/prod)에 독립적인 공유 리소스 관리
# - GitHub OIDC Provider (계정당 1개)
# - ECR Repository (이미지 태그로 dev/prod 구분)
# =============================================================================

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.84"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project    = "exchange-settlement"
      Layer      = "global"
      ManagedBy  = "terraform"
      Repository = "nomad-free/eks-gitops-provisioning"
    }
  }
}


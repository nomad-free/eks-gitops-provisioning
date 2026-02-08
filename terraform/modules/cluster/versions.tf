# ============================================
# 🆕 신규 - terraform/modules/cluster/versions.tf
# ============================================
# 모듈이 사용하는 Provider 버전 제약을 명시합니다.
#
# 왜 필요한가?
# - 모듈이 독립적으로 terraform init 가능하려면 required_providers 필요
# - 특히 random provider는 rds.tf, secrets-manager.tf에서 사용하므로 필수
# - 이것이 없으면 terraform init 시 "Could not load plugin" 에러 발생
#
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.84"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}
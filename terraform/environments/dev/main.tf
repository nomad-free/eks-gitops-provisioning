# ============================================
# 🆕 신규 - terraform/environments/dev/main.tf
# ============================================
# 역할: Dev 환경 전용 Terraform 루트 모듈
#
# 이 파일이 하는 일:
# 1. Global State에서 ECR URL 가져오기
# 2. 공유 모듈(modules/cluster) 호출
# 3. ArgoCD Helm Release 설치 (Bootstrap)
#
# 왜 ArgoCD가 여기 있는가?
# - Helm provider는 EKS cluster_endpoint를 필요로 함
# - module.cluster가 EKS를 생성하고, 이 값을 출력함
# - Helm provider는 루트 모듈에서 설정해야 함 (provider ↔ module 순환 의존 방지)
#

# ─────────────────────────────────────────────
# Data Sources
# ─────────────────────────────────────────────
# ⚠️ aws_caller_identity만 여기 유지 (S3 bucket 이름에 필요)
# aws_region, aws_partition은 모듈 내부에서 자체 선언
data "aws_caller_identity" "current" {}


# Global State에서 공유 리소스 참조 (ECR URL 등)
data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    bucket = "exchange-settlement-123456789"
    key    = "global/terraform.tfstate"
    region = var.aws_region
  }
}

# ─────────────────────────────────────────────
# 공유 인프라 모듈 호출
# ─────────────────────────────────────────────
module "cluster" {
  source = "../../modules/cluster"

  environment         = var.environment
  aws_region          = var.aws_region
  domain_name         = var.domain_name
  app_port            = var.app_port
  eks_cluster_version = var.eks_cluster_version
  allowed_cidrs       = var.allowed_cidrs

  # 🔄 Global State에서 가져온 값들을 모듈에 주입
  ecr_repository_url       = data.terraform_remote_state.global.outputs.ecr_repository_url
  ecr_repository_arn       = data.terraform_remote_state.global.outputs.ecr_repository_arn
  github_oidc_provider_arn = data.terraform_remote_state.global.outputs.github_oidc_provider_arn
}

# ─────────────────────────────────────────────
# ArgoCD Bootstrap (Helm Release)
# ─────────────────────────────────────────────
# 왜 Terraform으로 설치하는가?
# - ArgoCD는 "다른 모든 것을 배포하는 도구"
# - ArgoCD 자체를 배포할 도구가 필요 → Terraform (Bootstrap)
# - 이후 ArgoCD가 자기 자신을 업데이트하는 것도 가능 (Self-Manage)
#
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.7.16" # 2025 최신 안정 버전
  namespace        = "argocd"
  create_namespace = true

  # ArgoCD가 안정적으로 뜰 때까지 대기
  timeout = 600
  wait    = true

  values = [yamlencode({
    # ─── 글로벌 설정 ───
    global = {
      # Dev는 HA 불필요
      revisionHistoryLimit = 3
    }

    # ─── Server 설정 ───
    server = {
      # Cloudflare가 SSL 처리하므로 HTTP로 접근
      extraArgs = ["--insecure"]

      service = {
        type = "ClusterIP" # Ingress를 통해 노출
      }

      # Dev: 단일 리플리카
      replicas = 1

      resources = {
        requests = { cpu = "100m", memory = "128Mi" }
        limits   = { cpu = "500m", memory = "256Mi" }
      }
    }

    # ─── Repo Server (Git Clone 담당) ───
    repoServer = {
      replicas = 1
      resources = {
        requests = { cpu = "100m", memory = "128Mi" }
        limits   = { cpu = "500m", memory = "512Mi" }
      }
    }

    # ─── Application Controller (Sync 담당) ───
    controller = {
      resources = {
        requests = { cpu = "200m", memory = "256Mi" }
        limits   = { cpu = "1000m", memory = "512Mi" }
      }
    }

    # ─── Config ───
    configs = {
      params = {
        # Application 상태 체크 주기 (초)
        "controller.status.processors"    = "20"
        "controller.operation.processors" = "10"
      }
    }
  })]

  depends_on = [module.cluster]
}



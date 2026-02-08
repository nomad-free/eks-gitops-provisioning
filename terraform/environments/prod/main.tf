# Dev와 동일 구조, 다른 점:
# 1. variable "environment" default = "prod"
# 2. ArgoCD HA 설정 (replicas: 2)

# ─── Data Sources ───
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    bucket = "exchange-settlement-${data.aws_caller_identity.current.account_id}"
    key    = "global/terraform.tfstate"
    region = var.aws_region
  }
}

# ─── 공유 인프라 모듈 호출 ───
module "cluster" {
  source = "../../modules/cluster"

  environment              = var.environment
  aws_region               = var.aws_region
  domain_name              = var.domain_name
  app_port                 = var.app_port
  eks_cluster_version      = var.eks_cluster_version
  allowed_cidrs            = var.allowed_cidrs
  ecr_repository_url       = data.terraform_remote_state.global.outputs.ecr_repository_url
  github_oidc_provider_arn = data.terraform_remote_state.global.outputs.github_oidc_provider_arn
  ecr_repository_arn       = data.terraform_remote_state.global.outputs.ecr_repository_arn
}

# ─── ArgoCD Bootstrap (Prod HA) ───
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.7.16"
  namespace        = "argocd"
  create_namespace = true
  timeout          = 600
  wait             = true

  values = [yamlencode({
    global = {
      revisionHistoryLimit = 5
    }

    server = {
      extraArgs = ["--insecure"]
      service   = { type = "ClusterIP" }
      replicas  = 2 # 🔄 Prod: HA 구성
      resources = {
        requests = { cpu = "200m", memory = "256Mi" }
        limits   = { cpu = "1000m", memory = "512Mi" }
      }
    }

    repoServer = {
      replicas = 2 # 🔄 Prod: HA 구성
      resources = {
        requests = { cpu = "200m", memory = "256Mi" }
        limits   = { cpu = "1000m", memory = "1Gi" }
      }
    }

    controller = {
      resources = {
        requests = { cpu = "500m", memory = "512Mi" }
        limits   = { cpu = "2000m", memory = "1Gi" }
      }
    }

    configs = {
      params = {
        "controller.status.processors"    = "20"
        "controller.operation.processors" = "10"
      }
    }
  })]

  depends_on = [module.cluster]
}
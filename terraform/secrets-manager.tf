# "AWS Secrets Manager 시크릿 생성 + External Secrets Operator 설치 + IRSA 설정"

# 실수로 삭제해도 30일 내 복구 가능
# 0으로 설정하면 즉시 삭제 (위험!)
resource "aws_secretsmanager_secret" "app" {
  name                    = "${local.project_name}/${var.environment}/app-secrets"
  description             = "Application secrets (DB, API Key, JWT, Encryption) for ${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  # [중요] 초기값은 더미(REPLACE_ME)입니다. 배포 후 AWS 콘솔에서 실제 값으로 변경해야 합니다.
  secret_string = jsonencode({
    DB_HOST     = "REPLACE_ME"
    DB_PORT     = "5432"
    DB_NAME     = "REPLACE_ME"
    DB_USER     = "REPLACE_ME"
    DB_PASSWORD = "REPLACE_ME"

    API_KEY    = "REPLACE_ME" # 서버 간 통신용 (M2M)
    API_SECRET = "REPLACE_ME"

    JWT_SECRET     = "REPLACE_ME" # 관리자 로그인 토큰 발급용
    ENCRYPTION_KEY = "REPLACE_ME" # 민감 데이터 DB 저장 시 암호화용 (32byte)
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "cicd" {
  name                    = "${local.project_name}/${var.environment}/cicd-secrets"
  description             = "CI/CD pipeline secrets for ${var.environment}"
  recovery_window_in_days = 7
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "cicd" {
  secret_id = aws_secretsmanager_secret.cicd.id

  # CI/CD 전용 시크릿 (앱 시크릿과 다릅니다)
  secret_string = jsonencode({
    SLACK_WEBHOOK_URL    = "REPLACE_ME"
    CLOUDFLARE_API_TOKEN = "REPLACE_ME"
    CLOUDFLARE_ZONE_ID   = "REPLACE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# 📌 섹션 3: External Secrets Operator 설치
resource "helm_release" "external_secrets" {
  name = "external-secrets"

  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  # - 성능 최적화 및 AWS Secrets Manager 연동 속도 개선
  version          = "0.12.1"
  namespace        = "external-secrets"
  create_namespace = true

  values = [yamlencode({
    installCRDs = true
    serviceAccount = {
      create = true
      name   = "external-secrets"
    }
  })]
  depends_on = [time_sleep.wait_for_eks, module.external_secrets_irsa]
}

# 📌 섹션 4: External Secrets IRSA (IAM Role for ServiceAccount)# IRSA란?
# - Kubernetes ServiceAccount에 IAM Role 연결
# - Pod 레벨에서 AWS 권한 제어

module "external_secrets_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  # [2025.09 출시] IAM Module v5.50.0
  version   = "5.50.0"
  role_name = "${local.cluster_name}-external-secrets"
  # attach_external_secrets_policy: External Secrets 전용 정책 자동 연결
  # AWS에서 미리 만들어둔 정책으로 Secrets Manager 읽기 권한 부여
  attach_external_secrets_policy = true
  # 이 시크릿들만 읽을 수 있음 (최소 권한 원칙)
  external_secrets_secrets_manager_arns = [
    aws_secretsmanager_secret.app.arn
  ]
  # EKS OIDC Provider와 연결하여 ServiceAccount ↔ IAM Role 매핑
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
  tags = local.common_tags
}

# 📌 섹션 5: 애플리케이션 IRSA

# 용도: 애플리케이션 Pod에서 Secrets Manager 직접 접근
# (External Secrets 외에 앱에서 직접 시크릿 읽을 때 사용)
module "app_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.50.0"

  role_name = "${local.cluster_name}-secrets-manager"

  attach_external_secrets_policy = true
  external_secrets_secrets_manager_arns = [
    aws_secretsmanager_secret.app.arn
  ]

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      # Dev와 Prod 모두에서 사용 가능
      namespace_service_accounts = [
        "app-dev:app-sa", # Dev 환경 ServiceAccount
        "app-prod:app-sa" # Prod 환경 ServiceAccount
      ]
    }
  }

  tags = local.common_tags
}
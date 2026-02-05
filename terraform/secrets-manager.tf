# "AWS Secrets Manager 시크릿 생성 + External Secrets Operator 설치 + IRSA 설정"

# 실수로 삭제해도 30일 내 복구 가능
# 0으로 설정하면 즉시 삭제 (위험!)
resource "aws_secretsmanager_secret" "app" {
  name                    = "${local.project_name}/${var.environment}/app-secrets"
  description             = "Application secrets (DB, API Key, JWT, Encryption) for ${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7
  tags                    = local.common_tags
}


resource "aws_secretsmanager_secret_version" "app_db_credentials" {
  secret_id = aws_secretsmanager_secret.app.id

  # ---------------------------------------------------------------------------
  # 시크릿 내용
  # ---------------------------------------------------------------------------
  #
  # 자동으로 채워지는 값:
  # - DB_HOST: RDS 엔드포인트 (예: exchange-settlement-dev.xxx.us-east-1.rds.amazonaws.com)
  # - DB_PORT: 5432
  # - DB_NAME: exchange_db
  # - DB_USER: app_admin
  # - DB_PASSWORD: 자동 생성된 32자리 비밀번호
  #
  # 수동으로 채워야 하는 값 (REPLACE_ME):
  # - API_KEY, API_SECRET: 외부 API 키
  # - JWT_SECRET: JWT 토큰 서명용
  # - ENCRYPTION_KEY: 데이터 암호화용 (32바이트)
  #
  secret_string = jsonencode({
    # =========================================================================
    # 🗄️ 데이터베이스 설정 (자동 입력)
    # =========================================================================
    DB_HOST     = aws_db_instance.main.address       # RDS 엔드포인트 (호스트명만)
    DB_PORT     = tostring(local.db_port)            # "5432"
    DB_NAME     = local.db_name                      # "exchange_db"
    DB_USER     = local.db_username                  # "app_admin"
    DB_PASSWORD = random_password.db_password.result # 자동 생성된 비밀번호

    # =========================================================================
    # 🔌 데이터베이스 연결 URL (편의용)
    # =========================================================================
    # 일부 ORM/라이브러리에서 사용하는 연결 문자열 형식
    DATABASE_URL = "postgresql://${local.db_username}:${random_password.db_password.result}@${aws_db_instance.main.address}:${local.db_port}/${local.db_name}"

    # =========================================================================
    # 🔑 외부 API 키 (수동 입력 필요)
    # =========================================================================
    # 
    # ⚠️ 배포 후 AWS 콘솔에서 실제 값으로 변경하세요!
    # 
    # API_KEY: 서버 간 M2M(Machine-to-Machine) 통신용
    # - 외부 서비스에서 이 앱의 API를 호출할 때 사용
    # - x-api-key 헤더로 전달
    #
    # API_SECRET: API 요청 서명용 (선택적)
    # - HMAC 서명 등에 사용
    #
    API_KEY    = "REPLACE_ME_WITH_ACTUAL_API_KEY"
    API_SECRET = "REPLACE_ME_WITH_ACTUAL_API_SECRET"

    # =========================================================================
    # 🔐 보안 토큰 (수동 입력 필요)
    # =========================================================================
    #
    # JWT_SECRET: JSON Web Token 서명용
    # - 관리자 로그인 토큰 발급에 사용
    # - 최소 32자 이상 권장
    # - 예: openssl rand -hex 32 로 생성
    #
    # ENCRYPTION_KEY: 민감 데이터 암호화용
    # - 정확히 32바이트(256비트) 필요
    # - AES-256 암호화에 사용
    # - DB에 저장되는 민감 정보(memo 등) 암호화
    # - 예: openssl rand -hex 16 (32자리 hex = 16바이트... 아니, 32바이트 필요)
    # - 정확히: openssl rand -base64 32 | head -c 32
    #
    JWT_SECRET     = "REPLACE_ME_WITH_JWT_SECRET_MIN_32_CHARS"
    ENCRYPTION_KEY = "REPLACE_ME_32_BYTE_ENCRYPTION_KEY!" # 정확히 32자
  })

  # ---------------------------------------------------------------------------
  # 라이프사이클 설정
  # ---------------------------------------------------------------------------
  #
  # 왜 ignore_changes를 사용하는가?
  # - AWS 콘솔에서 API_KEY, JWT_SECRET 등을 수동 변경하면
  # - 다음 terraform apply 시 다시 REPLACE_ME로 덮어쓰는 것을 방지
  #
  # 단, DB 정보(호스트, 비밀번호 등)가 변경되면?
  # - RDS 재생성 시에만 변경됨 (드문 경우)
  # - 필요시 taint 명령으로 강제 재생성
  #   terraform taint aws_secretsmanager_secret_version.app_db_credentials
  #
  lifecycle {
    ignore_changes = [secret_string]
  }

  # ---------------------------------------------------------------------------
  # 의존성
  # ---------------------------------------------------------------------------
  depends_on = [aws_db_instance.main]
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


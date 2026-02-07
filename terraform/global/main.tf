# =============================================================================
# 🌐 Global Layer - 공유 리소스
# =============================================================================
#
# 이 파일의 리소스는 dev/prod 환경과 독립적으로 관리됩니다.
# dev를 destroy해도 여기 리소스는 영향 없음.
#
# 적용 순서: global → dev → prod (항상 global 먼저!)
#
# =============================================================================


data "aws_caller_identity" "current" {}

# =============================================================================
# 📌 섹션 1: GitHub OIDC Provider
# =============================================================================
#
# AWS 계정당 동일 URL의 OIDC Provider는 1개만 존재 가능
# dev/prod 모두 이 Provider를 참조하여 GitHub Actions 인증 수행
#
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Project   = local.project_name
    Layer     = "global"
    ManagedBy = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# 📌 섹션 2: ECR Repository (dev/prod 공유)
# =============================================================================
#
# 하나의 ECR을 dev/prod가 공유하고 이미지 태그로 구분:
#   - dev:  latest-dev, dev-{SHA}
#   - prod: latest-prod, v1.0.0-{SHA}
#
# 왜 공유하는가?
#   - dev에서 검증된 이미지를 prod에 그대로 배포 (동일 이미지 보장)
#   - ECR 레벨 분리보다 태그 기반 분리가 실무에서 더 일반적
#   - Lifecycle Policy로 전체 이미지 수를 통제
#
resource "aws_ecr_repository" "app" {
  name = "${local.project_name}-app"

  # ECR은 공유이므로 IMMUTABLE 설정
  # → 동일 태그로 덮어쓰기 불가 (latest-dev/latest-prod 제외)
  # 주의: latest-* 태그 사용 시 MUTABLE이어야 함
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project   = local.project_name
    Layer     = "global"
    ManagedBy = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "최근 50개 이미지만 유지 (dev+prod 합산)"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 50
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
# [github-oidc.tf]
# GitHub Actions를 위한 IAM Role 및 정책 정의

# 1. GitHub OIDC Provider 생성
resource "aws_iam_openid_connect_provider" "github" {
  count = var.environment == "dev" ? 1 : 0 # dev 환경에서만 생성 (필요시 조건 수정)

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
  tags = local.common_tags
}

# 2. IAM Role 생성 (GitHub Actions가 사용할 가면)
resource "aws_iam_role" "github_actions" {
  name = "github-actions-${local.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # 본인의 리포지토리 
            "token.actions.githubusercontent.com:sub" = "repo:nomad-free/eks-gitops-provisioning:*"
          }
        }
      }
    ]
  })
  tags = local.common_tags
}

# 3. 정책 연결: ECR 접근 (이미지 Push/Pull)
resource "aws_iam_role_policy" "ecr_access" {
  name = "ecr-access"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        # aws_ecr_repository.app 리소스가 정의되어 있어야 합니다.
        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}

# 4. 정책 연결: Secrets Manager (환경변수 읽기)
resource "aws_iam_role_policy" "secrets_access" {
  name = "secrets-manager-access"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${local.project_name}/*"
      }
    ]
  })
}

# 5. 정책 연결: Terraform 실행을 위한 전체 권한 (GitOps)
# 주의: Admin 권한에 준하므로 보안에 유의
resource "aws_iam_role_policy" "terraform_access" {
  name = "terraform-access"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # (1) 인프라 리소스 (EC2, EKS, S3 등) - 넓게 허용
      {
        Sid    = "InfrastructureAccess"
        Effect = "Allow"
        Action = [
          "ec2:*", "eks:*", "secretsmanager:*",
          "s3:*", "logs:*", "kms:*", "autoscaling:*",
          "elasticloadbalancing:*", "sts:GetCallerIdentity", "ecr:*"
        ]
        Resource = "*"
      },

      # (2) IAM '조회' 권한 - 안전하므로 전체 허용 (디버깅 용이)
      {
        Sid    = "IAMReadAccess"
        Effect = "Allow"
        Action = [
          "iam:List*", "iam:Get*", "iam:GenerateServiceLastAccessedDetails"
        ]
        Resource = "*"
      },

      # (3) IAM '쓰기' 권한 - [핵심] Resource Prefix 제한 적용
      # 오직 "exchange-settlement-dev-*" 로 시작하는 Role/Policy만 생성/삭제 가능
      {
        Sid    = "IAMWriteRestricted"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole",
          "iam:TagRole", "iam:UntagRole",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy",
          "iam:CreatePolicy", "iam:DeletePolicy",
          "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:SetDefaultPolicyVersion",
          "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider", "iam:TagOpenIDConnectProvider"
        ]
        Resource = [
          # [여기서 제한!] local.cluster_name 변수 활용
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.cluster_name}-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_name}-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/*"
        ]
      },

      # (4) PassRole 권한 - 역할 위임 제한
      # Terraform이 만든 Role을 EKS나 EC2에게 넘겨줄 때도 이름 제한
      {
        Sid      = "IAMPassRoleRestricted"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.cluster_name}-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = ["eks.amazonaws.com", "ec2.amazonaws.com"]
          }
        }
      },

      # (5) Service Linked Role 생성 (AWS 자동 생성 역할)
      {
        Sid      = "CreateServiceLinkedRole"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "*"
      }
    ]
  })
}
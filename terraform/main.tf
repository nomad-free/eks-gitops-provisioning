data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}



module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.13.0"
  name    = "${local.cluster_name}-vpc"
  cidr    = local.vpc_config[var.environment].cidr

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = local.vpc_config[var.environment].private_subnets
  public_subnets  = local.vpc_config[var.environment].public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = local.env_config[var.environment].single_nat_gateway
  one_nat_gateway_per_az = !local.env_config[var.environment].single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "karpenter.sh/discovery" = local.cluster_name
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "karpenter.sh/discovery"                      = local.cluster_name
  }
  tags = local.common_tags
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.31"
  cluster_name    = local.cluster_name
  cluster_version = var.eks_cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # 1. 생성자에게 자동 권한 부여 기능 끄기 (보안 강화 & 명시적 관리)
  enable_cluster_creator_admin_permissions = false

  # 2. 클러스터 접근 방식 설정 (API 방식 권장)
  authentication_mode = "API_AND_CONFIG_MAP"

  access_entries = {
    master_admin = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/Master-Admin"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    },

    # CI/CD 파이프라인을 위한 권한 (배포용)
    # -> github-oidc.tf 에서 만든 Role을 여기서 참조합니다.
    ci_cd_runner = {
      principal_arn = aws_iam_role.github_actions.arn

      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }


  # KMS 키 관리자 (Secret 암호화용 키 권한)
  kms_key_administrators = [
    # 1. 현재 이 Terraform을 실행하는 사람
    data.aws_caller_identity.current.arn,

    # 2. GitHub Actions Role (자동 연동)
    # github-oidc.tf에서 생성된 Role이 키 관리 권한도 갖도록 설정
    aws_iam_role.github_actions.arn
  ]

  cluster_addons = {
    # 역할: Pod끼리 이름으로 통신 (service-name.namespace → IP)
    # 예: app.app-dev.svc.cluster.local → 10.0.1.123
    coredns = {
      most_recent = true
    }

    # 역할: Service의 트래픽을 Pod으로 라우팅
    # 예: ClusterIP Service → 실제 Pod IP로 전달
    kube-proxy = {
      most_recent = true
    }
    # 역할: Pod에 VPC IP 직접 할당
    # 장점: Pod이 VPC 내 다른 리소스(RDS 등)와 직접 통신 가능
    #
    # ENABLE_PREFIX_DELEGATION: IP 주소 효율성 향상
    # 기존: 노드당 최대 ~30개 Pod
    # 활성화: 노드당 최대 ~110개 Pod (t3.medium 기준)
    vpc-cni = {
      most_recent    = true
      before_compute = true # 노드 생성 전에 CNI 먼저 설정
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    # 역할: PersistentVolume으로 EBS 사용
    # 예: 데이터베이스 Pod에 영구 스토리지 연결
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }

  eks_managed_node_group_defaults = {
    ami_type = "AL2023_x86_64_STANDARD"
  }
  eks_managed_node_groups = {
    main = {
      name           = "${local.cluster_name}-node"
      instance_types = local.node_config[var.environment].instance_types
      capacity_type  = local.node_config[var.environment].capacity_type

      min_size     = local.node_config[var.environment].min_size
      max_size     = local.node_config[var.environment].max_size
      desired_size = local.node_config[var.environment].desired_size

      labels = { Environment = var.environment }

      enable_irsa = true

      tags = {
        "k8s.io/cluster-autoscaler/enabled"               = "true"
        "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
      }
    }
  }

  enable_irsa = true

  tags = local.common_tags
}

# 3. [추가됨] EBS CSI Driver를 위한 IRSA Role
# (cluster_addons에서 참조 중이므로 이 블록이 꼭 필요합니다)
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "ebs-csi-${local.cluster_name}"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
  tags = local.common_tags
}

resource "aws_ecr_repository" "app" {
  name = "${local.project_name}-app"

  # MUTABLE: 같은 태그로 덮어쓰기 가능 (예: latest)
  # IMMUTABLE: 한번 푸시한 태그는 변경 불가 (프로덕션 권장)
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "최근 30개 이미지만 유지"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# EKS 클러스터가 완전히 준비될 때까지 대기
resource "time_sleep" "wait_for_eks" {
  # 모듈 생성 후 잠시 대기 (Access Entry 설정 전파 등 고려)
  depends_on = [module.eks]

  create_duration = "60s"
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
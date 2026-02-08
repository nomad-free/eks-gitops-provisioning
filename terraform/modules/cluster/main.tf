data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

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

  # ---------------------------------------------------------------------------
  # 클러스터 접근 제어
  # ---------------------------------------------------------------------------
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.allowed_cidrs
  cluster_endpoint_private_access      = true

  # 생성자에게 자동 admin 권한 부여 끄기 (보안 강화)
  enable_cluster_creator_admin_permissions = true

  # Access Entry 방식 사용 (최신 방식)
  authentication_mode = "API_AND_CONFIG_MAP"

  # ===========================================================================
  # 🔑 Access Entries (IAM Role -> K8s 권한 매핑)
  # ===========================================================================
  access_entries = {
    # 1. 마스터 관리자 (콘솔용 사용자)
    master_admin = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/Master-Admin"

      # 관리자는 별도 user_name 지정 불필요 (기본값 사용)
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }

    # 2. CI/CD Runner (GitHub Actions)
    ci_cd_runner = {
      principal_arn = aws_iam_role.github_actions.arn

      # ⭐⭐⭐ 핵심 변경: Kubernetes 내부 Username 고정 ⭐⭐⭐
      # 이 설정 덕분에 rbac.tf에서 복잡한 ARN 대신 "ci-cd-runner"라는 이름만 쓰면 됩니다.
      user_name = "ci-cd-runner"

      policy_associations = {
        # (1) 기본 리소스(Deployment, Service 등) 권한
        deploy = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = ["app-${var.environment}"]

          }
        }
        # (2) CRD 권한은 여기서 줄 수 없으므로, rbac.tf에서 "ci-cd-runner" 이름으로 부여함
      }
    }
  }

  # ---------------------------------------------------------------------------
  # KMS 키 관리자 (Secret 암호화용)
  # ---------------------------------------------------------------------------
  kms_key_administrators = [
    data.aws_caller_identity.current.arn,
    aws_iam_role.github_actions.arn
  ]

  # ---------------------------------------------------------------------------
  # EKS Addons
  # ---------------------------------------------------------------------------
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }

  # ---------------------------------------------------------------------------
  # Node Groups
  # ---------------------------------------------------------------------------
  eks_managed_node_group_defaults = {
    ami_type = "AL2023_x86_64_STANDARD"
  }

  eks_managed_node_groups = {
    main = {
      name           = "main"
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
  tags        = local.common_tags
}

# 3. [추가됨] EBS CSI Driver를 위한 IRSA Role
# (cluster_addons에서 참조 중이므로 이 블록이 꼭 필요합니다)
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.50.0"

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



# EKS 클러스터가 완전히 준비될 때까지 대기
resource "time_sleep" "wait_for_eks" {
  # 모듈 생성 후 잠시 대기 (Access Entry 설정 전파 등 고려)
  depends_on = [module.eks]

  create_duration = "60s"
}


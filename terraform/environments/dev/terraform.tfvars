# ============================================
# 🆕 신규 - terraform/environments/dev/terraform.tfvars
# ============================================
# 변경 전: terraform/dev.tfvars
# 변경 후: 환경 디렉토리 내로 이동 (같은 내용)
# 
# terraform.tfvars는 자동 로드되므로 -var-file 불필요!
#
environment         = "dev"
aws_region          = "us-east-1"
domain_name         = "playbuilder.xyz"
app_port            = 3000
eks_cluster_version = "1.34"
allowed_cidrs       = ["0.0.0.0/0"]
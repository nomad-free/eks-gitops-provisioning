# ============================================
# ✅ 변경 후 - terraform/modules/cluster/outputs.tf
# ============================================
# 변경 사항:
# 1. K8s 리소스 관련 output 3개 삭제
# 2. ArgoCD 관련 output 추가
# 3. external_secrets_role_arn 유지 (ArgoCD가 Helm values에서 참조)

output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "aws_region" {
  description = "AWS Region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of Private Subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of Public Subnet IDs"
  value       = module.vpc.public_subnets
}

output "cluster_name" {
  description = "EKS Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API Server Endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS Cluster CA Data"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_arn" {
  description = "EKS Cluster ARN"
  value       = module.eks.cluster_arn
}

output "oidc_provider_arn" {
  description = "EKS OIDC Provider ARN"
  value       = module.eks.oidc_provider_arn
}



output "github_actions_role_arn" {
  description = "IAM Role ARN for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "app_secrets_arn" {
  description = "App Secrets ARN"
  value       = aws_secretsmanager_secret.app.arn
  sensitive   = true
}

output "external_secrets_role_arn" {
  description = "IAM Role ARN for External Secrets (ArgoCD Helm values에서 참조)"
  value       = module.external_secrets_irsa.iam_role_arn
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "app_domain" {
  description = "Application Domain"
  value       = var.environment == "prod" ? var.domain_name : "${var.environment}.${var.domain_name}"
}

# 🆕 ArgoCD 관련 출력
output "argocd_url" {
  description = "ArgoCD Server URL (port-forward 후 접근)"
  value       = "kubectl port-forward svc/argocd-server -n argocd 8080:443"
}

# RDS outputs (모듈에서 직접 출력)
output "rds_endpoint" {
  description = "RDS 엔드포인트"
  value       = "${aws_db_instance.main.address}:${aws_db_instance.main.port}"
}
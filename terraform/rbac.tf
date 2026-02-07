# 🔐 terraform/rbac.tf - GitHub Actions를 위한 CRD 권한 (최소 권한 원칙)
# =============================================================================
#
# 문제:
# - AmazonEKSEditPolicy는 기본 K8s 리소스만 접근 가능
# - ExternalSecret, SecretStore는 CRD라서 접근 불가
#
# 해결:
# - EditPolicy 유지 (기본 리소스용)
# - CRD 접근용 ClusterRole + ClusterRoleBinding 별도 추가
#
# =============================================================================

# -----------------------------------------------------------------------------
# ClusterRole: External Secrets CRD 접근 권한

resource "kubernetes_cluster_role" "github_actions_external_secrets" {
  metadata {
    name = "github-actions-external-secrets"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # ExternalSecret, SecretStore CRD에 대한 권한
  rule {
    api_groups = ["external-secrets.io"]
    resources  = ["externalsecrets", "secretstores", "clustersecretstores"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  depends_on = [time_sleep.wait_for_eks]
}

resource "kubernetes_cluster_role_binding" "github_actions_external_secrets" {
  metadata {
    name = "github-actions-external-secrets"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.github_actions_external_secrets.metadata[0].name
  }

  # ⭐ 핵심: 복잡한 ARN 연산 없이 위에서 지정한 user_name만 쓰면 됩니다.
  subject {
    kind      = "User"
    name      = "ci-cd-runner" # aws_eks_access_entry에서 지정한 이름
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [kubernetes_cluster_role.github_actions_external_secrets]
}
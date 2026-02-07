#  K8s ServiceAccount 및 Namespace 직접 생성
# - Terraform이 K8s Namespace와 ServiceAccount를 직접 생성
# - IRSA Role ARN을 ServiceAccount annotation에 직접 주입

resource "kubernetes_service_account_v1" "app_sa" {
  metadata {
    name      = "app-sa"
    namespace = kubernetes_namespace_v1.app_ns.metadata[0].name

    labels = {
      "app.kubernetes.io/name"       = "app"
      "app.kubernetes.io/component"  = "serviceaccount"
      "app.kubernetes.io/part-of"    = "exchange-settlement"
      "app.kubernetes.io/managed-by" = "terraform"
    }

    annotations = {
      # IRSA Role ARN 주입
      "eks.amazonaws.com/role-arn" = module.app_irsa.iam_role_arn
    }
  }


  # 보안: 앱이 K8s API를 직접 호출하지 않는다면 false 권장
  automount_service_account_token = false

  depends_on = [kubernetes_namespace_v1.app_ns]
}

resource "kubernetes_namespace_v1" "app_ns" {

  metadata {
    name = "app-${var.environment}"

    # -------------------------------------------------------------------------
    # Labels
    # -------------------------------------------------------------------------
    labels = {
      # 프로젝트 식별
      "app.kubernetes.io/part-of"    = "exchange-settlement"
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = var.environment


      # enforce: 정책 위반 시 Pod 생성 거부
      # restricted: 가장 엄격한 보안 정책

      "pod-security.kubernetes.io/enforce"         = "restricted"
      "pod-security.kubernetes.io/enforce-version" = "v1.34"

      # audit/warn 레벨도 설정 (로그 기록용)
      "pod-security.kubernetes.io/audit" = "restricted"
      "pod-security.kubernetes.io/warn"  = "restricted"
    }
  }


  lifecycle {
    # prevent_destroy = true
    # Kustomize가 동일 Namespace를 생성하려 할 때 충돌 방지
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}
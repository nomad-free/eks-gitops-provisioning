resource "helm_release" "ingress_nginx" {
  name = "ingress-nginx"


  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  # - K8s 1.34 호환성 확보 및 HTTP/3 지원 강화
  version          = "4.11.3"
  namespace        = "ingress-nginx"
  create_namespace = true

  # values: Helm Chart 설정값 (YAML 형식)
  # replicaCount: Ingress Controller Pod 개수      
  # Prod에서 2개인 이유:
  # - 1개 Pod 장애 시에도 트래픽 처리
  # - Rolling Update 시 무중단 배포

  values = [yamlencode({
    controller = {
      replicaCount = local.env_config[var.environment].ingress_replicas

      service = {
        type = "LoadBalancer" # AWS NLB 자동 생성
        annotations = {
          # [2025 Best Practice] AWS Load Balancer Controller v3.x 호환 설정
          # ip: NLB → Pod IP 직접 연결 (성능 최적화!)
          # instance: NLB → NodePort → Pod (추가 홉 발생)
          # ip 모드 조건: VPC CNI 필수 (main.tf에서 설정됨)

          "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
          "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
        }
      }
      # │  CPU request    │  100m (0.1코어) │  200m (0.2코어)   
      resources = {
        requests = {
          cpu    = var.environment == "prod" ? "200m" : "100m"
          memory = var.environment == "prod" ? "256Mi" : "128Mi"
        }
        limits = {
          cpu    = var.environment == "prod" ? "500m" : "200m"
          memory = var.environment == "prod" ? "512Mi" : "256Mi"
        }
      }

      metrics = {
        enabled = true
      }

      # [2025 표준] 고가용성을 위한 토폴로지 분산 제약 조건 추가
      topologySpreadConstraints = [
        {
          # 각 존(Zone) 간의 파드 개수 차이가 1개를 넘지 않도록 합니다. (균등 분배)
          maxSkew = 1
          # 파드들을 AWS의 **서로 다른 가용 영역(AZ, 예: ap-northeast-2a, 2c)**에 골고루 퍼뜨립니다.
          topologyKey = "topology.kubernetes.io/zone"
          # whenUnsatisfiable: 조건 충족 불가 시 행동
          # DoNotSchedule: 분산 안 되면 배포 대기
          # ScheduleAnyway: 어쨌든 배포 (덜 엄격
          whenUnsatisfiable = "DoNotSchedule"
          labelSelector = {
            matchLabels = {
              "app.kubernetes.io/name"      = "ingress-nginx"
              "app.kubernetes.io/component" = "controller"
            }
          }
        }
      ]
    }
  })]
  depends_on = [
    time_sleep.wait_for_eks,
    module.eks.eks_managed_node_groups
  ]
}

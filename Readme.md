사용법:

Dev 확인: make dev

Dev 배포: make deploy-dev

Prod 확인: make prod

Prod 배포: make deploy-prod


1. 🚨 Secrets Manager 에러 ("Already scheduled for deletion")
원인: Terraform이 Secrets Manager(app-secrets, cicd-secrets)를 생성하려고 했지만, 이전에 terraform destroy 등을 통해 삭제된 후 **"복구 대기 기간(Recovery Window)"**에 걸려 있는 상태입니다. (AWS는 실수로 지운 시크릿을 복구할 수 있도록 기본 30일간 데이터를 남겨둡니다.)

해결 방법: AWS CLI를 사용하여 "복구 없이 즉시 완전 삭제" 해야 합니다. 터미널에 아래 명령어를 입력하세요.

Bash
# dev/app-secrets 완전 삭제
aws secretsmanager delete-secret --secret-id exchange-settlement/dev/app-secrets --force-delete-without-recovery --region us-east-1

# dev/cicd-secrets 완전 삭제
aws secretsmanager delete-secret --secret-id exchange-settlement/dev/cicd-secrets --force-delete-without-recovery --region us-east-1
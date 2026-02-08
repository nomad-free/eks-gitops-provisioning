# ============================================
# ✅ 변경 후 - terraform/Makefile
# ============================================
# -reconfigure 불필요! 각 환경이 독립된 디렉토리
#
TF = terraform

# ─── Global (변경 없음) ───
global-init:
	cd global && $(TF) init -backend-config=backends/global.hcl
global-plan:
	cd global && $(TF) plan
global-apply:
	cd global && $(TF) apply

# ─── Dev (디렉토리 변경) ───
dev-init:
	cd environments/dev && $(TF) init -backend-config=backend.hcl

dev-plan:
	cd environments/dev && $(TF) plan
	# terraform.tfvars가 자동 로드되므로 -var-file 불필요!

dev-apply:
	cd environments/dev && $(TF) plan -out=tfplan && $(TF) apply tfplan

dev-output:
	cd environments/dev && $(TF) output

# ─── Prod (디렉토리 변경) ───
prod-init:
	cd environments/prod && $(TF) init -backend-config=backend.hcl

prod-plan:
	cd environments/prod && $(TF) plan

prod-apply:
	cd environments/prod && $(TF) plan -out=tfplan && $(TF) apply tfplan

prod-output:
	cd environments/prod && $(TF) output

# ─── 안전장치: 전체 적용 ───
all-dev: global-init global-apply dev-init dev-apply
all-prod: global-init global-apply prod-init prod-apply
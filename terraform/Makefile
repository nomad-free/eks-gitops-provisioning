# =============================================================================
# Terraform Makefile
# =============================================================================
# 적용 순서: global → dev/prod (항상 global 먼저!)
# =============================================================================

TF = terraform

# ─── Global (환경 독립) ───
global-init:
	cd global && $(TF) init -reconfigure -backend-config=backends/global.hcl

global-plan:
	cd global && $(TF) plan

global-apply:
	cd global && $(TF) apply

global-output:
	cd global && $(TF) output

# ─── Dev ───
dev-init:
	$(TF) init -reconfigure -backend-config=backends/dev.hcl

dev-plan:
	$(TF) plan -var-file=dev.tfvars

dev-apply:
	$(TF) plan -var-file=dev.tfvars -out=tfplan && $(TF) apply tfplan

dev-output:
	$(TF) output

# ─── Prod ───
prod-init:
	$(TF) init -reconfigure -backend-config=backends/prod.hcl

prod-plan:
	$(TF) plan -var-file=prod.tfvars

prod-apply:
	$(TF) plan -var-file=prod.tfvars -out=tfplan && $(TF) apply tfplan

prod-output:
	$(TF) output

# ─── 전체 적용 (순서 보장) ───
all-dev: global-init global-apply dev-init dev-apply
all-prod: global-init global-apply prod-init prod-apply
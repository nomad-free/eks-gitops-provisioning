.PHONY: dev prod

dev:
	@echo "Switching to DEV..."
	terraform init -reconfigure -backend-config=backends/dev.hcl
	terraform plan -var-file=dev.tfvars

prod:
	@echo "Switching to PROD..."
	terraform init -reconfigure -backend-config=backends/prod.hcl
	terraform plan -var-file=prod.tfvars

deploy-dev:
	terraform apply -var-file=dev.tfvars -auto-approve

deploy-prod:
	terraform apply -var-file=prod.tfvars -auto-approve
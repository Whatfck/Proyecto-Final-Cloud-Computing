.PHONY: help init plan apply destroy validate fmt clean deploy build backend-build

# Default target
help:
	@echo "════════════════════════════════════════════════════════"
	@echo "📦 Marketplace Terraform Commands"
	@echo "════════════════════════════════════════════════════════"
	@echo ""
	@echo "📋 Quick Commands:"
	@echo "  make apply       - Deploy infrastructure to AWS"
	@echo "  make destroy     - Destroy all AWS resources"
	@echo ""
	@echo "🔧 Terraform Commands:"
	@echo "  make init        - Initialize Terraform"
	@echo "  make plan        - Preview infrastructure changes"
	@echo "  make validate    - Validate Terraform configuration"
	@echo "  make fmt         - Format Terraform files"
	@echo ""
	@echo "🚀 Deployment Commands:"
	@echo "  make deploy      - Build backend + upload to S3"
	@echo "  make backend-build - Build backend locally"
	@echo ""
	@echo "🧹 Utility Commands:"
	@echo "  make clean       - Remove local build artifacts"
	@echo "  make help        - Show this help message"
	@echo ""
	@echo "════════════════════════════════════════════════════════"

# Build backend and upload to S3
deploy:
	@echo "🚀 Building and deploying backend to S3..."
	@./deploy.sh us-east-1
	@echo "✓ Backend deployment complete"

# Build backend locally
backend-build:
	@echo "📦 Building backend locally..."
	@(cd backend && npm install --production && \
	echo "✓ Backend build complete")

# Initialize Terraform
init:
	@echo "🔧 Initializing Terraform..."
	@(cd infra/terraform && terraform init && \
	echo "✓ Terraform initialized")

# Format Terraform files
fmt:
	@echo "📏 Formatting Terraform files..."
	@(cd infra/terraform && terraform fmt -recursive && \
	echo "✓ Terraform files formatted")

# Validate Terraform configuration
validate:
	@echo "✅ Validating Terraform configuration..."
	@(cd infra/terraform && terraform validate && \
	echo "✓ Configuration is valid")

# Show Terraform plan
plan:
	@echo "📋 Generating Terraform plan..."
	@(cd infra/terraform && terraform plan -var-file=terraform.tfvars && \
	echo "✓ Plan generated")

# Apply Terraform changes
apply:
	@echo "🚀 Deploying infrastructure to AWS..."
	@echo "This will create/update resources. Please review!"
	@(cd infra/terraform && \
	terraform apply -var-file=terraform.tfvars -auto-approve && \
	echo "" && \
	echo "✅ Deployment complete!" && \
	echo "" && \
	echo "📊 Infrastructure Summary:" && \
	terraform output)

# Destroy all resources
destroy:
	@echo "⚠️  WARNING: This will DELETE all AWS resources!"
	@echo "This action cannot be undone."
	@read -p "Are you sure? Type 'destroy' to confirm: " confirm && \
	[ "$$confirm" = "destroy" ] || (echo "❌ Cancelled"; exit 1)
	@echo ""
	@echo "🗑️  Destroying infrastructure..."
	@(cd infra/terraform && \
	terraform destroy -var-file=terraform.tfvars -auto-approve && \
	echo "✓ Resources destroyed")

# Clean up local artifacts
clean:
	@echo "🧹 Cleaning up local artifacts..."
	@rm -f backend.tar.gz
	@rm -f backend_*.tar.gz
	@rm -rf backend/node_modules
	@rm -f infra/terraform/terraform.tfstate*
	@rm -rf infra/terraform/.terraform
	@echo "✓ Cleanup complete"

# Full workflow: build -> deploy -> apply
full-deploy: backend-build deploy apply
	@echo "✅ Full deployment workflow complete!"

# Show Terraform state
state:
	@echo "📊 Terraform State:"
	@cd infra/terraform && terraform state list

# Output infrastructure details
output:
	@echo "📤 Infrastructure Outputs:"
	@cd infra/terraform && terraform output

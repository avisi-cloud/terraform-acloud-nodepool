# Contributor workflow for the avisi-cloud/nodepool/acloud Terraform module.
#
#   make            show this help
#   make docs       regenerate the terraform-docs blocks in every README
#   make docs-check verify those blocks are up to date (CI-safe, no writes)
#
# Formatting, section order and table settings live in .terraform-docs.yml.
# The recursion flags below are what extend a run to examples/*, so adding a new
# example directory needs no change here.

TERRAFORM      ?= terraform
TERRAFORM_DOCS ?= terraform-docs
TF_DOCS_FLAGS  := --recursive --recursive-path examples --recursive-include-main
EXAMPLES       := $(sort $(dir $(wildcard examples/*/main.tf)))

.DEFAULT_GOAL := help
.PHONY: help docs docs-check docs-preview fmt fmt-check validate check clean

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

## --- documentation ---------------------------------------------------------

docs: ## Regenerate the generated block in README.md and every examples/*/README.md
	$(TERRAFORM_DOCS) $(TF_DOCS_FLAGS) .

docs-check: ## Fail if any generated README block is out of date (use in CI)
	$(TERRAFORM_DOCS) $(TF_DOCS_FLAGS) --output-check .

docs-preview: ## Print the generated reference for the root module to stdout
	@$(TERRAFORM_DOCS) --output-file "" .

## --- terraform -------------------------------------------------------------

fmt: ## Rewrite all .tf files to canonical format
	$(TERRAFORM) fmt -recursive .

fmt-check: ## Fail if any .tf file is not canonically formatted
	$(TERRAFORM) fmt -check -recursive .

validate: ## terraform init + validate for the module and every example
	@$(TERRAFORM) init -backend=false -input=false >/dev/null || exit 1
	@$(TERRAFORM) validate || exit 1
	@for dir in $(EXAMPLES); do \
		echo "==> $$dir"; \
		$(TERRAFORM) -chdir=$$dir init -backend=false -input=false >/dev/null || exit 1; \
		$(TERRAFORM) -chdir=$$dir validate || exit 1; \
	done

check: fmt-check docs-check ## Everything CI should enforce on a pull request

clean: ## Remove local terraform working directories
	@find . -type d -name .terraform -prune -exec rm -rf {} +
	@find . -type f -name .terraform.lock.hcl -delete

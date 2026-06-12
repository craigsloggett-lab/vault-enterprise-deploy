MODULE_REPO ?= https://github.com/craigsloggett/terraform-aws-vault-enterprise.git
BRANCH      ?=
COMMIT_MSG  ?= Validate recent module changes

.PHONY: help
.PHONY: bump latest
.PHONY: init validate fmt lint docs check plan
.PHONY: stage commit push ship iterate logs
.PHONY: cycle update

help:
	@printf '%s\n' "Development cycle targets (run in order):"
	@printf '\n'
	@printf '%s\n' "  make bump BRANCH=<name>  Point main.tf at latest commit on BRANCH"
	@printf '%s\n' "  make latest              Point main.tf at latest release tag"
	@printf '%s\n' "  make check               init-upgrade, validate, fmt, lint, docs"
	@printf '%s\n' "  make ship                stage, commit, push"
	@printf '\n'
	@printf '%s\n' "Roll-ups:"
	@printf '%s\n' "  make cycle BRANCH=<name> bump + check + iterate + ship"
	@printf '%s\n' "  make update              latest + check + ship"
	@printf '\n'
	@printf '%s\n' "Individual steps:"
	@printf '%s\n' "  init      terraform init -upgrade"
	@printf '%s\n' "  validate  terraform validate"
	@printf '%s\n' "  fmt       terraform fmt --recursive"
	@printf '%s\n' "  lint      tflint --recursive --format=compact"
	@printf '%s\n' "  docs      terraform-docs ."
	@printf '%s\n' "  plan      terraform plan"
	@printf '%s\n' "  stage     git add ."
	@printf '%s\n' "  commit    git commit -m '\$$(COMMIT_MSG)'"
	@printf '%s\n' "  push      git push"
	@printf '%s\n' "  iterate   ./scripts/iterate-development.sh"
	@printf '%s\n' "  logs      source scripts/environment.sh, then get-cloud-init-logs.sh"
	@printf '\n'
	@printf '%s\n' "Override: MODULE_REPO=<url>"

bump:
	@: $${BRANCH:?BRANCH is required, e.g. make bump BRANCH=cool-new-feature}
	@SHA=$$(git ls-remote $(MODULE_REPO) refs/heads/$(BRANCH) | cut -f1); \
	[ -n "$$SHA" ] || { printf '%s\n' "Error: Branch '$(BRANCH)' not found on $(MODULE_REPO)" >&2; exit 1; }; \
	DIR=$$(mktemp -d); TMP=$$DIR/main.tf; \
	trap 'rm -f "$$TMP" "$$TMP.new"; rmdir "$$DIR"' EXIT INT TERM; \
	sed '/# tflint-ignore: terraform_module_pinned_source/d' main.tf > "$$TMP" && \
	sed "s|ref=[^\"]*|ref=$$SHA|" "$$TMP" > "$$TMP.new" && mv "$$TMP.new" "$$TMP" && \
	awk '/source *= *"git::/ { print "# tflint-ignore: terraform_module_pinned_source" } { print }' "$$TMP" > "$$TMP.new" && mv "$$TMP.new" "$$TMP" && \
	terraform fmt "$$TMP" >/dev/null && \
	mv "$$TMP" main.tf && \
	printf 'updated main.tf -> %s\n' "$$SHA"

latest:
	@TAG=$$(git ls-remote --tags --refs --sort=-v:refname $(MODULE_REPO) | head -n1 | sed 's|.*refs/tags/||'); \
	[ -n "$$TAG" ] || { printf '%s\n' "Error: No tags found on $(MODULE_REPO)" >&2; exit 1; }; \
	DIR=$$(mktemp -d); TMP=$$DIR/main.tf; \
	trap 'rm -f "$$TMP" "$$TMP.new"; rmdir "$$DIR"' EXIT INT TERM; \
	sed '/# tflint-ignore: terraform_module_pinned_source/d' main.tf > "$$TMP" && \
	sed "s|ref=[^\"]*|ref=$$TAG|" "$$TMP" > "$$TMP.new" && mv "$$TMP.new" "$$TMP" && \
	terraform fmt "$$TMP" >/dev/null && \
	mv "$$TMP" main.tf && \
	printf 'updated main.tf -> %s\n' "$$TAG"

init:
	terraform init -upgrade

validate:
	terraform validate

fmt:
	terraform fmt --recursive

lint:
	tflint --recursive --format=compact

docs: init
	terraform-docs .

plan:
	terraform plan

check: init validate fmt lint docs

stage:
	git add .

commit: stage
	git commit -m '$(COMMIT_MSG)'

push:
	git push

ship: commit push

iterate:
	./scripts/iterate-development.sh

logs:
	@if [ ! -f scripts/environment.sh ]; then \
		printf '%s\n' "Error: scripts/environment.sh not found." >&2; \
		printf '%s\n' "Copy scripts/environment.sh.example and edit it." >&2; \
		exit 1; \
	fi
	@. ./scripts/environment.sh && \
	scripts/get-cloud-init-logs.sh

cycle: COMMIT_MSG = Validate recent module changes
cycle: bump check iterate ship
	@printf '\n'
	@printf '%s\n' "Deploy triggered."

update: COMMIT_MSG = Bump the module version number
update: latest check ship
	@printf '\n'
	@printf '%s\n' "Deploy triggered."

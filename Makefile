MODULE_REPO ?= https://github.com/craigsloggett/terraform-aws-vault-enterprise.git
BRANCH      ?=
COMMIT_MSG  ?= Validate recent module changes

.PHONY: help
.PHONY: bump latest
.PHONY: init validate fmt lint docs check
.PHONY: stage commit push ship
.PHONY: cycle update

help:
	@echo "Development cycle targets (run in order):"
	@echo ""
	@echo "  make bump BRANCH=<name>  Point main.tf at latest commit on BRANCH"
	@echo "  make latest              Point main.tf at latest release tag"
	@echo "  make check               init-upgrade, validate, fmt, lint, docs"
	@echo "  make ship                stage, commit, push"
	@echo ""
	@echo "Roll-ups:"
	@echo "  make cycle BRANCH=<name> bump + check + ship"
	@echo "  make update              latest + check + ship"
	@echo ""
	@echo "Individual steps:"
	@echo "  init      terraform init -upgrade"
	@echo "  validate  terraform validate"
	@echo "  fmt       terraform fmt --recursive"
	@echo "  lint      tflint --recursive --format=compact"
	@echo "  docs      terraform-docs ."
	@echo "  stage     git add ."
	@echo "  commit    git commit -m '\$$(COMMIT_MSG)'"
	@echo "  push      git push"
	@echo ""
	@echo "Override: MODULE_REPO=<url>"

bump:
	@: $${BRANCH:?BRANCH is required, e.g. make bump BRANCH=cool-new-feature}
	@SHA=$$(git ls-remote $(MODULE_REPO) refs/heads/$(BRANCH) | cut -f1); \
	[ -n "$$SHA" ] || { echo "Error: Branch '$(BRANCH)' not found on $(MODULE_REPO)" >&2; exit 1; }; \
	TMP=$$(mktemp -d)/main.tf; \
	trap 'rm -f "$$TMP" "$$TMP.new"' EXIT INT TERM; \
	sed '/# tflint-ignore: terraform_module_pinned_source/d' main.tf > "$$TMP" && \
	sed "s|ref=[^\"]*|ref=$$SHA|" "$$TMP" > "$$TMP.new" && mv "$$TMP.new" "$$TMP" && \
	awk '/source *= *"git::/ { print "# tflint-ignore: terraform_module_pinned_source" } 1' "$$TMP" > "$$TMP.new" && mv "$$TMP.new" "$$TMP" && \
	terraform fmt "$$TMP" >/dev/null && \
	mv "$$TMP" main.tf

latest:
	@TAG=$$(git ls-remote --tags --refs --sort=-v:refname $(MODULE_REPO) | head -n1 | sed 's|.*refs/tags/||'); \
	[ -n "$$TAG" ] || { echo "Error: No tags found on $(MODULE_REPO)" >&2; exit 1; }; \
	TMP=$$(mktemp -d)/main.tf; \
	trap 'rm -f "$$TMP" "$$TMP.new"' EXIT INT TERM; \
	sed '/# tflint-ignore: terraform_module_pinned_source/d' main.tf > "$$TMP" && \
	sed "s|ref=[^\"]*|ref=$$TAG|" "$$TMP" > "$$TMP.new" && mv "$$TMP.new" "$$TMP" && \
	terraform fmt "$$TMP" >/dev/null && \
	mv "$$TMP" main.tf && \
	echo "updated main.tf -> $$TAG"

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

check: init validate fmt lint docs

stage:
	git add .

commit: stage
	git commit -m '$(COMMIT_MSG)'

push:
	git push

ship: commit push

cycle: COMMIT_MSG = Validate recent module changes
cycle: bump check ship
	@echo ""
	@echo "Deploy triggered."

update: COMMIT_MSG = Bump the module version number
update: latest check ship
	@echo ""
	@echo "Deploy triggered."

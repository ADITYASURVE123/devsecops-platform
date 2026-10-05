SHELL := /bin/bash
CLUSTER      ?= devsecops
SERVICES     := orders-api inventory-api
TAG          ?= dev
ENV          ?= kind
REPO_URL     ?= $(shell git remote get-url origin 2>/dev/null)
ARGOCD_VER   ?= v2.12.4
AWS_REGION   ?= ap-south-1
TF_DIR       := infra/terraform/envs/demo

.PHONY: help lint test ai-test build kind-up kind-load bootstrap up destroy helm-lint \
	    tf-bootstrap tf-init eks-up eks-down jenkins-stop jenkins-start check-aws-region

help:           ## list targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/ -/'

lint:           ## ruff on both services
	for s in $(SERVICES); do (cd services/$$s && ruff check .); done

test:           ## pytest + coverage gate
	for s in $(SERVICES); do (cd services/$$s && pip install -q -r requirements-dev.txt && pytest -q --cov=app --cov-fail-under=80); done

ai-test:        ## unit tests for the advisory reviewer
	cd ci/ai-reviewer && python3 -m unittest -v

build:          ## build both images locally
	for s in $(SERVICES); do docker build -t $$s:$(TAG) services/$$s; done

helm-lint:      ## lint + render the chart
	helm lint deploy/charts/service -f deploy/envs/kind/orders-api.yaml
	helm template orders-api deploy/charts/service -f deploy/envs/kind/orders-api.yaml >/dev/null

kind-up:        ## single-node kind cluster
	kind create cluster --name $(CLUSTER) --config kind/kind-config.yaml

kind-load: build ## load local images into kind
	for s in $(SERVICES); do kind load docker-image $$s:$(TAG) --name $(CLUSTER); done

bootstrap:      ## install Argo CD and apply the root app-of-apps (push your repo to GitHub first)
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VER)/manifests/install.yaml
	kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
	ENV=$(ENV) REPO_URL=$(REPO_URL) ESO_ENABLED=$${ESO_ENABLED:-false} ESO_ROLE_ARN=$${ESO_ROLE_ARN:-} AWS_REGION=$(AWS_REGION) \
	  envsubst < deploy/argocd/root.yaml | kubectl apply -f -

up: kind-up kind-load bootstrap   ## one command: local cluster + GitOps platform

destroy:        ## delete the local cluster
	kind delete cluster --name $(CLUSTER)

tf-bootstrap:   ## one-time: S3 bucket for remote state (native S3 locking)
	cd infra/terraform/bootstrap && terraform init && terraform apply

check-aws-region:
	@test "$(AWS_REGION)" = "ap-south-1" || { echo "AWS_REGION must be ap-south-1 for this project"; exit 1; }

tf-bootstrap tf-init eks-up eks-down jenkins-stop jenkins-start: check-aws-region

tf-init:
	cd $(TF_DIR) && terraform init -backend-config=backend.hcl

eks-up:         ## COSTS MONEY (EKS ~ $$0.10/h + NAT + nodes). Build, demo, then eks-down.
	cd $(TF_DIR) && terraform apply
	aws eks update-kubeconfig --region $(AWS_REGION) --name $$(cd $(TF_DIR) && terraform output -raw cluster_name)
	ENV=dev ESO_ENABLED=true ESO_ROLE_ARN=$$(cd $(TF_DIR) && terraform output -raw external_secrets_role_arn) $(MAKE) bootstrap

eks-down:       ## delete Argo apps first (frees load balancers), then destroy everything
	-kubectl -n argocd delete application root --wait=true --timeout=300s
	cd $(TF_DIR) && terraform destroy

jenkins-stop:   ## stop the Jenkins EC2 between sessions (EBS still billed, compute is not)
	aws ec2 stop-instances --region $(AWS_REGION) --instance-ids $$(cd $(TF_DIR) && terraform output -raw jenkins_instance_id)

jenkins-start:
	aws ec2 start-instances --region $(AWS_REGION) --instance-ids $$(cd $(TF_DIR) && terraform output -raw jenkins_instance_id)

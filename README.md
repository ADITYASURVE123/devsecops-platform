# AI-Assisted DevSecOps Platform on AWS EKS (Jenkins, GitOps, Canary)

A production-style delivery platform for two small FastAPI services:

`git push` -> Jenkins CI (quality + security gates) -> advisory LLM review -> ECR -> Argo CD GitOps -> Argo Rollouts canary with Prometheus analysis -> Grafana/Alertmanager -> automatic rollback.

**Design principle: AI advises, deterministic checks decide.** The LLM step can comment but never block, approve or promote.

> Status: this repo was generated and statically checked (YAML parse, unit tests for the AI reviewer, shell/Make dry-run). Terraform, Helm rendering and the live cluster flows have **not** been executed yet. Follow `docs/build-guide.md` phase by phase and fix what your environment shows. Screenshots/GIFs and measured numbers are yours to add.

## Architecture
See [docs/architecture.md](docs/architecture.md) (Mermaid diagram) and [docs/decisions.md](docs/decisions.md) (12 decisions, including trade-offs).

## Tech stack
Python/FastAPI, Docker, Jenkins (declarative multibranch), Gitleaks, Trivy, Syft, SonarQube, ruff, pytest, Terraform (VPC, EKS, ECR, EC2, IRSA, S3 state), Helm, Argo CD (app-of-apps), Argo Rollouts, kube-prometheus-stack, Grafana, Alertmanager, Kyverno, External Secrets, Ollama.

## Layout
```
services/        two FastAPI services + tests + Dockerfiles
deploy/          Helm chart, per-env values, Argo CD app-of-apps, platform manifests
infra/terraform/ bootstrap (state bucket), modules (vpc, ecr, eks, jenkins), envs/demo
ci/              AI reviewer (stdlib Python + tests), Jenkins shared library step
observability/   kube-prometheus-stack values, alert/SLO rules, Grafana dashboards
policies/        Kyverno ClusterPolicies
docs/            architecture, decisions, runbooks, concepts, build guide, interview prep
Jenkinsfile      CI pipeline        Makefile  one-command up/destroy
```

## How to run (cheap path: kind, 8 GB RAM friendly)
Prereqs: Docker, kind, kubectl, helm, Python 3.12, and this repo pushed to GitHub (branch `main`, public or add repo credentials to Argo CD).
```bash
sed -i 's#<YOUR_GH_USER>#yourname#' deploy/argocd/bootstrap/values.yaml   # then commit + push
make test ai-test          # unit tests
make up                    # kind cluster + images + Argo CD + whole platform
scripts/kind-demo-watch.sh # port-forwards for Argo CD, Grafana, Prometheus
scripts/demo-release.sh good orders-api kind
scripts/demo-release.sh bad  orders-api kind   # watch the automatic rollback
make destroy
```
Tip for 8 GB machines: wait for each Argo app to go Healthy before opening dashboards, and close other heavy apps. If it still thrashes, set `retention`/replicas lower or sync platform apps one at a time.

## AWS demo (costs money; read docs/cost-notes.md first)
AWS regional resources and the Terraform state bucket are configured for `ap-south-1`. Follow the detailed [AWS execution steps](EXECUTION_STEPS.md): configure AWS credentials for that region, bootstrap the state bucket, copy and fill in the Terraform example files, then run `make eks-up`. Configure Jenkins as described in [docs/jenkins-setup.md](docs/jenkins-setup.md), and always finish with `make eks-down`.

The project rejects other region values in Make and Terraform. AWS IAM and AWS Budgets are account-global services; their roles and budget alert are associated with this deployment but do not reside in a particular AWS region.

## Failure handling
Runbooks for the three required incidents: [bad deploy](docs/runbooks/bad-deploy.md), [pod crashloop](docs/runbooks/pod-crashloop.md), [high latency](docs/runbooks/high-latency.md). Each maps to a Prometheus alert.

## Known limitations (honest list)
- kind's default CNI does not enforce NetworkPolicy; EKS does (VPC CNI network policy enabled).
- Canary weights are replica-based (25/50/100); exact 10% needs a traffic router.
- The Jenkins EC2 instance cannot reach a laptop-hosted Ollama without a tunnel; the AI step then skips by design.
- A 1.5B local model gives shallow reviews.
- Grafana admin password in values is demo-only.

## Lessons learned
(Fill in after you build it: what broke, what you changed, what you measured.)

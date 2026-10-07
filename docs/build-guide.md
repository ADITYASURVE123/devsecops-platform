# Build guide: phases, verification, interview checkpoints

This guide is a learning path for understanding and reproducing the platform. The project has already been deployed to AWS EKS and a successful `orders-api` canary has been observed, but that does not mean every checklist item below has been repeated from a clean account. See [verified project evidence](resume-and-linkedin.md) for what was observed, and distinguish implemented configuration from a verified live outcome.

Each phase ends with questions to help you explain the design in an interview. For a low-cost first pass, use the local `kind` path; the AWS path incurs charges.

## Phase 0: repo + decisions
Done in this repo (`docs/architecture.md`, `docs/decisions.md`). Push to GitHub as `devsecops-platform` (public) and replace `<YOUR_GH_USER>` in `deploy/argocd/bootstrap/values.yaml`.
Q: Why advisory AI? Why kind first? What is an ADR?

## Phase 1: app + Docker + kind + Helm
```bash
make lint test ai-test
make build && docker run --rm -p 8000:8000 orders-api:dev      # curl localhost:8000/health, /orders, /metrics
make helm-lint                                                  # needs helm
```
Verify: tests pass with coverage >= 80; image runs as UID 10001 (`docker run --rm orders-api:dev id`); `/metrics` shows `http_requests_total`.
Q: Why multi-stage and non-root? Why label metrics by route template, not raw path? Why a readiness vs liveness probe?

## Phase 2: Terraform (EKS costs money from here)
```bash
cd infra/terraform/bootstrap && terraform init && terraform apply -var region=ap-south-1 -var bucket_name=<unique>
cd ../envs/demo && cp backend.hcl.example backend.hcl && cp terraform.tfvars.example terraform.tfvars   # edit both
make tf-init && terraform -chdir=infra/terraform/envs/demo plan
```
Both the state bucket (`backend.hcl`) and the regional infrastructure must use `ap-south-1`; Terraform and Make reject another deployment region. AWS IAM and Budgets are account-global services.
Verify: the plan shows the intended VPC, ECR repositories, Jenkins EC2 + instance profile, EKS, and budget. Review and run `terraform fmt -recursive`, `terraform validate`, and a plan before applying any infrastructure. A previous live deployment was completed, but always validate the exact Terraform files and account you are about to use.
Q: Why remote state with locking? Why an instance profile instead of access keys? Why IMMUTABLE ECR tags?

## Phase 3: Jenkins CI (see `docs/jenkins-setup.md`)
Verify: the configured PR build runs Gitleaks, ruff, pytest, SonarQube, and Trivy; main builds publish to ECR. Deliberately failing a test or adding a fake secret is a useful controlled exercise, but do not add secret-shaped test data to a real repository without understanding scanner behavior.
Q: Why scan filesystem and image? Why pinned tool images? What happens if Sonar is down?

## Phase 4: Argo CD + GitOps
```bash
make up              # kind: cluster + images + Argo CD + app-of-apps (repo must be on GitHub, branch main)
scripts/kind-demo-watch.sh
```
Verify: all Applications Synced/Healthy in the Argo UI; changing `tag:` in Git changes the cluster; `kubectl edit` is reverted by self-heal.
Q: Push vs pull deploys? What does selfHeal do? Why does Jenkins commit instead of `kubectl apply`?

## Phase 5: observability + SLOs
Verify: Grafana dashboards "Services: golden signals + SLO", "Rollouts & cluster health", "Jenkins builds" load; Prometheus > Alerts lists the rules. Put the Slack webhook in SSM (EKS) or `kubectl -n monitoring create secret generic alertmanager-slack --from-literal=webhook-url=<url>` (kind).
Q: Four golden signals? How is the error budget computed? Why alert on symptoms not causes?

## Phase 6: canary + analysis
```bash
kubectl argo rollouts get rollout orders-api -n apps -w     # install the kubectl plugin
scripts/demo-release.sh good orders-api kind                # promotes 25 -> 50 -> 100
scripts/demo-release.sh bad  orders-api kind                # analysis fails, auto-abort, rollback
```
Verify: a good release reaches Healthy at 100%. For a bad release, do not assume rollback from the manifest or script comments: observe the failed AnalysisRun, rollout abort, and stable ReplicaSet. That bad-release outcome is still pending end-to-end verification in the current evidence record. Only then record a rollback time or publish a rollback demo.
Q: How do you isolate canary metrics? What if there is no traffic? Why 25% not 10%?

## Phase 7: hardening
Verify: `kubectl run bad --image=nginx:latest -n apps` is rejected by Kyverno; NetworkPolicy blocks a curl from another namespace (on EKS); `kubectl get hpa,pdb -n apps`; ExternalSecret becomes `SecretSynced` on EKS.
Q: Enforce vs Audit? What does a PDB protect against? Why IRSA over node role?

## Phase 8: AI reviewer
```bash
ollama pull qwen2.5-coder:1.5b && git diff main > /tmp/d.txt
python3 ci/ai-reviewer/reviewer.py pr-review --input /tmp/d.txt
OLLAMA_URL=http://127.0.0.1:9 python3 ci/ai-reviewer/reviewer.py pr-review --input /tmp/d.txt   # skip path, exit 0
```
Q: How do you defend against prompt injection in a diff? How do you cap cost/latency? Why not let the LLM block merges?

## Phase 9: portfolio polish
Capture genuine screenshots or a short recording of the current working system, with secrets and account identifiers removed. Re-run a clean local `make up`/`make destroy` cycle if you want to claim local reproducibility. Add numerical resume claims only after measuring them and preserving the source evidence in your own notes.
Q: What would you do differently at 50 services? What breaks first? What is your biggest remaining risk?

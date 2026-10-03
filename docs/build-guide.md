# Build guide: phases, verification, interview checkpoints

Do the phases in order. Each ends with three questions; answer them out loud before moving on. Everything runs on kind first.

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
cd infra/terraform/bootstrap && terraform init && terraform apply -var bucket_name=<unique>
cd ../envs/demo && cp backend.hcl.example backend.hcl && cp terraform.tfvars.example terraform.tfvars   # edit both
make tf-init && terraform -chdir=infra/terraform/envs/demo plan
```
Verify: plan shows VPC, 2 ECR repos, Jenkins EC2 + instance profile, EKS, budget. Run `terraform fmt -recursive` and `terraform validate` first; I could not run them offline.
Q: Why remote state with locking? Why an instance profile instead of access keys? Why IMMUTABLE ECR tags?

## Phase 3: Jenkins CI (see `docs/jenkins-setup.md`)
Verify: PR build runs Gitleaks, ruff, pytest, Sonar gate, Trivy; a deliberately failing test or a fake `AKIA...` key fails the build; main builds push to ECR.
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
Verify: good release reaches Healthy at 100%; bad release shows Degraded/aborted and traffic stays on stable. Record both as GIFs. Note the timestamps for the rollback metric.
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

## Phase 9: polish
Fill README screenshots/GIFs, record a 2-3 minute demo, run `make destroy` and `make up` again to prove reproducibility, finish `docs/resume-and-linkedin.md` with your measured numbers.
Q: What would you do differently at 50 services? What breaks first? What is your biggest remaining risk?

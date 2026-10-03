# Resume bullets, LinkedIn, walkthrough, next steps

## What to measure (do this before writing bullets; never invent numbers)
| Metric | How to measure |
|---|---|
| Pipeline duration | Average of the last 10 main builds in the Jenkins dashboard (Prometheus plugin) |
| Time to detect + auto-rollback a bad release | Timestamp push of the bad commit, then `RolloutAborted` alert / rollout status in Argo; use the Argo CD history and rollout events |
| Scan findings fixed | Trivy report counts HIGH/CRITICAL before vs after fixing, saved from build logs |
| Coverage | Coverage % from the pytest report |
| Cost per demo session | AWS Cost Explorer for the session day |
| Rebuild reproducibility | Time for `make destroy && make up` (kind) and terraform apply to Healthy (EKS) |

## Resume bullets (fill the brackets with YOUR measured values; delete a bullet if you did not measure it)
- Built a Jenkins CI pipeline for 2 Python microservices with Gitleaks, Trivy, SonarQube and pytest quality gates; fixed [N] HIGH/CRITICAL findings and held coverage at [X]%, with an average build time of [M] min.
- Implemented GitOps delivery on AWS EKS using Argo CD app-of-apps and Argo Rollouts canaries with Prometheus-based analysis; demonstrated automatic rollback of a faulty release in [T] seconds.
- Provisioned VPC, EKS, ECR and Jenkins with Terraform (remote state, IRSA, instance-profile auth, no static AWS keys); reduced idle spend with teardown automation and budget alerts, with a typical demo session costing about $[C].
- Designed Prometheus/Grafana/Alertmanager observability with a 99.5% availability SLO, error-budget panels and 3 incident runbooks; added Kyverno policies, NetworkPolicies, HPA and PDBs; built an advisory LLM PR reviewer (Ollama) that cannot block deploys.

## LinkedIn summary (one paragraph)
I built an AI-assisted DevSecOps delivery platform on AWS EKS: Jenkins CI with secret, dependency, image and code-quality gates; GitOps deployment through Argo CD; and Argo Rollouts canaries that automatically roll back when Prometheus metrics degrade. Infrastructure is Terraform with keyless AWS auth, observability covers golden signals, SLOs and alerting with runbooks, and Kyverno enforces cluster policy. A local-LLM pull-request reviewer assists reviewers but is deliberately advisory: AI advises, deterministic checks decide. Repo and demo: [link].

## 2-minute walkthrough script
"This project is a delivery platform for two small Python services. The services are trivial on purpose; the platform is the point. When I open a pull request, Jenkins runs secret scanning, lint, tests with a coverage gate, a SonarQube quality gate and Trivy scans, and a local LLM posts an advisory review. That review can never block anything; deterministic checks decide. On main, Jenkins builds the image, scans it, generates an SBOM, pushes to ECR using the instance profile, so there are no stored AWS keys, and then commits an image-tag change to Git. Jenkins never touches the cluster. Argo CD notices the commit and deploys through Argo Rollouts, shifting traffic in steps while a Prometheus analysis watches error rate and p95 latency of just the canary pods. I demoed a good release that promotes fully and a bad release that fails analysis and rolls back automatically in [T] seconds. Grafana shows golden signals and an error budget for a 99.5% SLO, Alertmanager routes alerts to Slack with runbooks, and Kyverno, NetworkPolicies, HPAs and PDBs harden the cluster. Everything is reproducible with Terraform and a Makefile, and I run it on kind first and EKS only for short demos to control cost. If I had more time I would add exact traffic splitting with an ingress and image signing with cosign."

## What I'd improve next
1. Cosign image signing plus a Kyverno `verifyImages` policy.
2. NGINX or Gateway API traffic routing for exact 10% canary weights.
3. Separate config repo with PR-based promotion between dev and prod environments.
4. Multi-window multi-burn-rate SLO alerts (fast and slow burn).
5. Jenkins agents as ephemeral pods and Jenkins config as code (JCasC).
6. Trivy Operator or Kubescape for continuous in-cluster scanning.
7. Loki for logs and OpenTelemetry tracing.
8. Karpenter or cluster-autoscaler for node scaling.
9. Chaos experiments (Litmus/Chaos Mesh) to test the alerts and runbooks.
10. A stronger remote model behind the same advisory interface, with eval tests.

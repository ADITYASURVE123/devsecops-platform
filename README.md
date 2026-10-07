# DevSecOps Delivery Platform on AWS

**A portfolio project showing how code moves from a Git commit to a monitored Kubernetes release.**

This project deploys two small Python/FastAPI services through a security-conscious CI pipeline and a GitOps-based release process. It is designed to make the platform engineering practices visible and explainable—not to imply that a small demo cluster is production infrastructure.

> **Project status — October 7, 2026:** Jenkins main build #10 succeeded and published both service images to ECR. The services were deployed to EKS in `ap-south-1`; both APIs returned healthy responses and each rollout had four available replicas. A good `orders-api` canary completed with a successful Prometheus analysis. The bad-release automatic abort/rollback is **not yet verified end to end**. Details and resume-safe wording are in [verified project evidence](docs/resume-and-linkedin.md).

## Why this project is worth a look

- **A real delivery path, not just YAML:** Jenkins builds and scans container images, then updates Git; Argo CD pulls the desired state and deploys it.
- **Security controls at multiple stages:** secret scanning, dependency/image scanning, code-quality checks, least-privilege AWS access, Kubernetes policies, and non-root workloads.
- **Progressive delivery with observability:** Argo Rollouts uses Prometheus analysis during canary promotion; dashboards and alerts support investigation.
- **A deliberate AI boundary:** the LLM reviewer can provide advisory feedback but cannot approve code, bypass CI checks, or promote a deployment.
- **Designed to be explainable:** architecture decisions, runbooks, interview questions, and a beginner-oriented build guide are included.

## What happens after a change

```text
Developer push
      |
      v
Jenkins: Gitleaks -> lint/tests -> SonarQube -> Trivy -> image + SBOM
      |                                      \
      | main branch only                     \ advisory review (non-blocking)
      v
Amazon ECR -> Git image-tag update -> Argo CD -> Argo Rollouts canary
                                                     |
                                               Prometheus analysis
                                                     |
                                           Grafana / Alertmanager
```

Jenkins uses its EC2 instance profile to publish to ECR and does not run `kubectl`. Git is the deployment source of truth; Argo CD applies changes from Git. The diagram describes the intended workflow; individual capabilities and live demo outcomes are distinguished in the [evidence notes](docs/resume-and-linkedin.md).

## Verified demo highlights

- Jenkins main build #10 succeeded and pushed both service images to ECR.
- Argo CD reported the applications Synced and Healthy during verification.
- Both service health endpoints returned `{"status":"ok"}`; both services had four available replicas.
- A good `orders-api` release passed its AnalysisRun and finished with four replicas.
- Automatic rollback after a deliberately bad release remains unverified. Do not describe that scenario as a completed demo until the failed analysis and return to the previously stable ReplicaSet are observed.

## Technology

| Area | Tools |
|---|---|
| Services | Python, FastAPI, pytest, ruff |
| CI and software supply chain | Jenkins, Gitleaks, SonarQube, Trivy, Syft |
| Cloud and infrastructure | AWS EKS, ECR, VPC, Terraform, EC2 instance profile, IRSA |
| Delivery | Helm, Argo CD, Argo Rollouts |
| Operations | Prometheus, Grafana, Alertmanager, Kubernetes probes/HPA/PDB |
| Policy and secrets | Kyverno, External Secrets Operator, AWS Systems Manager Parameter Store |
| AI-assisted review | Ollama-backed advisory reviewer |

## Repository map

| Path | What you will find |
|---|---|
| [`services/`](services/) | The two small API services, tests, and container build files |
| [`Jenkinsfile`](Jenkinsfile) | CI stages and main-branch image publishing |
| [`infra/terraform/`](infra/terraform/) | AWS infrastructure modules, environment, and state bootstrap |
| [`deploy/`](deploy/) | Helm chart, environment values, Argo CD bootstrap, and platform configuration |
| [`observability/`](observability/) | Prometheus rules and Grafana dashboards |
| [`policies/`](policies/) | Kubernetes admission policies |
| [`ci/ai-reviewer/`](ci/ai-reviewer/) | The optional LLM reviewer and its tests |
| [`docs/`](docs/) | Architecture, decisions, runbooks, build guide, interview prep, and resume material |

## Try it locally first

The local `kind` path avoids AWS infrastructure charges. Use Linux, macOS, or WSL2 with Docker, `make`, Git, `kubectl`, Helm, kind, and Python installed. For the full GitOps demo, push your fork to GitHub and set the repository URL in `deploy/argocd/bootstrap/values.yaml` first; see the [build guide](docs/build-guide.md).

```bash
make lint test ai-test
make helm-lint
make up
```

After bootstrap, inspect the cluster with `kubectl get applications -n argocd` and `kubectl get pods -A`. For teardown:

```bash
make destroy
```

To exercise a release, read [the canary demo instructions](docs/build-guide.md#phase-6-canary--analysis) first. The demo script edits a manifest, commits, and pushes it; only run it from a clean branch/worktree when you understand which remote branch receives the commit. The bad-release path should be treated as an experiment until its analysis failure and automatic rollback are confirmed.

## AWS deployment

The AWS regional resources and Terraform state bucket are configured for **`ap-south-1`**. AWS IAM and AWS Budgets are account-global and are not region-scoped. AWS deployment can incur charges, including EKS, NAT Gateway, EC2, storage, and data transfer.

1. Read [AWS execution steps](EXECUTION_STEPS.md) and [cost notes](docs/cost-notes.md).
2. Configure credentials securely; never commit access keys, `terraform.tfvars`, or backend state files.
3. Check the active AWS identity and region before provisioning.
4. Provision and validate the environment following the guide.
5. Tear down demo infrastructure when finished and check AWS Cost Explorer for residual resources.

Do not leave the EKS environment running just to keep a portfolio demo available. The README describes setup; the [verified evidence](docs/resume-and-linkedin.md) records what was actually observed.

## Security and design highlights

- Jenkins gets short-lived AWS credentials through an EC2 instance profile; permissions are scoped to the required ECR repositories.
- Jenkins updates Git rather than accessing the Kubernetes API. Argo CD performs deployment from the declared Git state.
- Cluster workloads use least-privilege service-account identity where AWS access is required.
- The LLM receives redacted, size-limited input and is advisory only. Deterministic checks control the build and release path.
- Canary percentages are replica-based (25%, 50%, then 100%); exact traffic percentages require a traffic router.
- The sample Grafana credentials and small Ollama model are for demonstration, not production use.

More detail: [architecture](docs/architecture.md), [design decisions](docs/decisions.md), [incident runbooks](docs/runbooks/), and [cost notes](docs/cost-notes.md).

## Resume and interview material

- [Evidence-based resume bullets, LinkedIn summary, and walkthrough](docs/resume-and-linkedin.md)
- [Project-specific interview questions](docs/interview-prep.md)
- [Step-by-step learning/build guide](docs/build-guide.md)

Use only claims you can demonstrate and explain. No pipeline duration, rollback time, cost, coverage percentage, or vulnerability count is claimed unless it has been measured and recorded.

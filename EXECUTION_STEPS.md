# AWS Deployment — Execution Steps

> **Stack:** VPC → ECR → Jenkins EC2 → EKS → Argo CD (GitOps) → Kyverno + ESO + Prometheus  
> **Cost warning:** EKS (~$0.10/h) + NAT Gateway + Spot nodes.  Run `make eks-down` when done.
> Regional AWS resources and the Terraform state bucket are restricted to `ap-south-1`. IAM and AWS Budgets are account-global services.

---

## Prerequisites — Install These First

| Tool | Minimum Version | Install |
|------|----------------|---------|
| AWS CLI | v2 | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| Terraform | ≥ 1.10.0 | https://developer.hashicorp.com/terraform/downloads |
| kubectl | ≥ 1.30 | https://kubernetes.io/docs/tasks/tools/ |
| Helm | ≥ 3.15 | https://helm.sh/docs/intro/install/ |
| Docker Desktop | latest | https://www.docker.com/products/docker-desktop/ |
| Git | any | https://git-scm.com/ |

---

## Phase 0 — AWS Account & Credentials

### 0.1 Configure AWS credentials

```bash
aws configure
# AWS Access Key ID     : <your-access-key>
# AWS Secret Access Key : <your-secret-key>
# Default region name   : ap-south-1
# Default output format : json
```

### 0.2 Verify identity

```bash
aws sts get-caller-identity
aws configure get region
# Confirm the configured region is ap-south-1 before continuing.
```

Expected output — you should see your account ID, not an error:

```json
{
  "UserId": "AIDA...",
  "Account": "123456789012",
  "Arn": "arn:aws:iam::123456789012:user/yourname"
}
```

### 0.3 Get your public IP (needed for the firewall allow-list)

```bash
curl -s https://checkip.amazonaws.com
# e.g. 203.0.113.55  →  use 203.0.113.55/32 below
```

---

## Phase 1 — Bootstrap Remote State (one-time only)

This creates an S3 bucket to store Terraform state so it is never lost.

### 1.1 Run bootstrap

```bash
cd infra/terraform/bootstrap
terraform init
terraform apply -var="region=ap-south-1" -var="bucket_name=devsecops-tfstate-<YOUR_AWS_ACCOUNT_ID>"
# Type  yes  when prompted
```

> Replace `<YOUR_AWS_ACCOUNT_ID>` with your 12-digit account ID (from Step 0.2).  
> The bucket name must be **globally unique**. Note the bucket name — you need it in Step 2.1.

---

## Phase 2 — Configure the Demo Environment

### 2.1 Create `backend.hcl` from the example

```bash
cd infra/terraform/envs/demo
cp backend.hcl.example backend.hcl
```

Edit `backend.hcl` — replace `<YOUR_STATE_BUCKET>` with your actual bucket name:

```hcl
bucket       = "devsecops-tfstate-<YOUR_AWS_ACCOUNT_ID>"
key          = "demo/terraform.tfstate"
region       = "ap-south-1"
encrypt      = true
use_lockfile = true
```

### 2.2 Create `terraform.tfvars` from the example

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` — fill in your real values:

```hcl
my_ip_cidr   = "203.0.113.55/32"   # your public IP from Step 0.3 (with /32)
budget_email = "you@example.com"    # email to receive cost alerts
```

> Optional overrides (defaults are fine for a demo):
> ```hcl
> region                = "ap-south-1"
> name                  = "devsecops"
> budget_usd            = 10
> jenkins_instance_type = "t3.small"
> node_instance_type    = "t3.medium"
> ```

---

## Phase 3 — Provision AWS Infrastructure

### 3.1 Initialise Terraform with remote backend

```bash
# From the repo root:
make tf-init
```

Or manually:

```bash
cd infra/terraform/envs/demo
terraform init -backend-config=backend.hcl
```

### 3.2 Preview what will be created

```bash
cd infra/terraform/envs/demo
terraform plan
```

Resources created: VPC, subnets, NAT gateway, ECR repos (`orders-api`, `inventory-api`), Jenkins EC2 (t3.small), EKS cluster (1.30) with 2 Spot t3.medium nodes, IAM roles (IRSA for External Secrets), AWS Budget alert.

### 3.3 Apply — this provisions everything (~15–20 min)

Before running `make eks-up`, push this repository to GitHub as described in Phase 4. This target also bootstraps Argo CD, which needs to fetch the repository. If you want to provision first, use the manual `terraform apply` below, then continue with Phases 4 and 5.

```bash
# From the repo root:
make eks-up
```

Or step by step:

```bash
cd infra/terraform/envs/demo
terraform apply          # type  yes  when prompted  (~15 min)

# Then update local kubeconfig:
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name $(terraform output -raw cluster_name)
```

### 3.4 Verify the cluster is reachable

```bash
kubectl get nodes
# Both nodes should be in  Ready  state
```

---

## Phase 4 — Push This Repo to GitHub (complete before `make eks-up`)

Argo CD pulls from GitHub, so your repo must be public (or use a deploy key for private).

### 4.1 Create a new GitHub repo

Go to https://github.com/new — name it `devsecops-platform`, leave it empty, copy the HTTPS URL.

### 4.2 Push

```bash
# From the repo root:
git remote set-url origin https://github.com/<YOUR_GITHUB_USERNAME>/devsecops-platform.git
git push -u origin main
```

> Note your repo URL — e.g. `https://github.com/ADITYASURVE123/devsecops-platform.git`

---

## Phase 5 — Bootstrap Argo CD (GitOps)

This installs Argo CD on EKS and applies the root App-of-Apps that manages every workload.

```bash
# From the repo root:
ENV=dev \
REPO_URL=https://github.com/<YOUR_GITHUB_USERNAME>/devsecops-platform.git \
ESO_ENABLED=true \
ESO_ROLE_ARN=$(cd infra/terraform/envs/demo && terraform output -raw external_secrets_role_arn) \
AWS_REGION=ap-south-1 \
make bootstrap
```

Or using the full `make eks-up` target (does Steps 3.3 + 5 together):

```bash
make eks-up
```

### 5.1 Get the Argo CD admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### 5.2 Access the Argo CD UI

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
# Open https://localhost:8080  (login: admin / password from above)
```

---

## Phase 6 — Set Up Jenkins

### 6.1 Get the Jenkins public IP

```bash
cd infra/terraform/envs/demo
terraform output public_ip
```

Open `http://<JENKINS_IP>:8080` in your browser.

### 6.2 Unlock Jenkins (get initial password via SSM — no SSH key needed)

```bash
INSTANCE_ID=$(cd infra/terraform/envs/demo && terraform output -raw jenkins_instance_id)
aws ssm start-session --target $INSTANCE_ID
# Inside the session:
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 6.3 Install required Jenkins plugins

Install these in **Manage Jenkins → Plugins → Available**:

- Pipeline
- Git
- GitHub Branch Source
- Docker Pipeline
- SonarQube Scanner
- Prometheus metrics
- Credentials Binding
- SCM Skip

### 6.4 Add Jenkins credentials

Go to **Manage Jenkins → Credentials → Global → Add Credential**:

| ID | Kind | Value |
|----|------|-------|
| `sonarqube-token` | Secret text | Your SonarQube token |
| `github-token` | Secret text | GitHub PAT (for PR comments) |
| `github-token-user` | Username + Password | GitHub username + PAT (for config commits) |

### 6.5 Configure environment variables in Jenkins

**Manage Jenkins → System → Global properties → Environment variables:**

| Variable | Value |
|----------|-------|
| `AWS_REGION` | `ap-south-1` |
| `ECR_REGISTRY` | `<AWS_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com` |
| `OLLAMA_URL` | `http://localhost:11434` *(optional — AI reviewer)* |

### 6.6 Configure SonarQube server

**Manage Jenkins → System → SonarQube servers:**  
Name: `sonarqube`, URL: `http://<your-sonarqube-host>:9000`

### 6.7 Create the Multibranch Pipeline

1. **New Item** → name: `devsecops-platform` → **Multibranch Pipeline**
2. **Branch Sources** → GitHub → enter repo URL → add `github-token` credential
3. **Discover:** branches, pull requests, tags
4. **Add GitHub webhook** at:  
   `http://<JENKINS_IP>:8080/github-branch-source/webhook/`  
   (in your GitHub repo → Settings → Webhooks)

### 6.8 Verify instance profile (no stored AWS keys)

```bash
# On the Jenkins EC2 via SSM:
aws sts get-caller-identity
# Should show  devsecops-jenkins-*  role — not your personal user
```

---

## Phase 7 — Verify the Full Pipeline

### 7.1 Trigger a build

Push any commit to `main`:

```bash
git commit --allow-empty -m "chore: trigger initial pipeline run"
git push origin main
```

### 7.2 Watch the pipeline stages

In Jenkins UI, the build should run these stages in order:

```
Checkout → Secrets scan (Gitleaks) → Lint + unit tests →
SonarQube quality gate → Trivy filesystem scan →
Build images → Image scan + SBOM → Push to ECR →
GitOps: bump image tag
```

### 7.3 Verify images in ECR

```bash
aws ecr describe-images --repository-name orders-api --region ap-south-1
aws ecr describe-images --repository-name inventory-api --region ap-south-1
```

### 7.4 Verify Argo CD synced the new tag

```bash
kubectl -n argocd get applications
# All apps should show  Synced  and  Healthy
```

### 7.5 Check running pods

```bash
kubectl get pods -A
# Look for:  argocd, orders-api, inventory-api, external-secrets,
#            kyverno, argo-rollouts, monitoring  namespaces
```

---

## Phase 8 — Access Observability (Grafana)

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
# Open http://localhost:3000  (default: admin / prom-operator)
```

Pre-built dashboards are in `observability/manifests/`:
- `dashboard-services.yaml` — orders-api & inventory-api RED metrics
- `dashboard-rollouts.yaml` — Argo Rollouts canary progress
- `dashboard-jenkins.yaml` — CI pipeline metrics

---

## Phase 9 — Tear Down (to stop AWS charges)

### 9.1 Delete all Argo CD apps first (releases load balancers)

```bash
make eks-down
# — or manually:
kubectl -n argocd delete application root --wait=true --timeout=300s
cd infra/terraform/envs/demo && terraform destroy    # type  yes
```

### 9.2 Stop Jenkins between sessions (saves compute cost, EBS still billed)

```bash
make jenkins-stop   # stop EC2
make jenkins-start  # when you need it again
```

---

## Quick Reference — All Make Targets

```bash
make help             # list all targets

# Local dev (no AWS cost)
make lint             # ruff on both services
make test             # pytest + 80% coverage gate
make build            # build Docker images locally
make helm-lint        # lint the Helm chart
make kind-up          # create local kind cluster
make up               # full local cluster (kind + Argo CD)
make destroy          # delete local kind cluster

# AWS
make tf-bootstrap     # one-time: create S3 state bucket
make tf-init          # terraform init with remote backend
make eks-up           # provision infra + deploy platform (~15-20 min) 💰
make eks-down         # delete everything (stop billing)
make jenkins-stop     # stop Jenkins EC2 (keep EBS)
make jenkins-start    # restart Jenkins EC2
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `terraform init` fails on backend | Check bucket name in `backend.hcl` matches exactly |
| `kubectl get nodes` — no nodes ready | Wait 5 min; Spot provisioning can be slow |
| Jenkins can't reach ECR | Check the instance profile is attached (`aws sts get-caller-identity` on the EC2) |
| Argo CD apps stuck `OutOfSync` | Verify `REPO_URL` in `make bootstrap` matches your GitHub remote exactly |
| Trivy scan fails on HIGH/CRITICAL | Update base images in `services/*/Dockerfile` to latest `python:3.12-slim` |
| SonarQube quality gate times out | Ensure SonarQube server name in Jenkins is `sonarqube` (case-sensitive) |
| Build fails `ruff check` | Run `ruff check --fix services/` locally and commit the fix |

---

## Cost Estimate

| Resource | Approx. cost |
|----------|-------------|
| EKS control plane | $0.10/h |
| 2× t3.medium Spot nodes | ~$0.03/h each |
| NAT Gateway | ~$0.045/h + data |
| Jenkins t3.small EC2 | ~$0.023/h |
| ECR storage | ~$0.10/GB-month |
| **Total (running 8h)** | **~$2–3** |

> Always run `make eks-down` after your demo session.  
> Budget alert fires at 80% of $10/month (set in `terraform.tfvars`).

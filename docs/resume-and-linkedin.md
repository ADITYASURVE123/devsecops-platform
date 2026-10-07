# Resume bullets, LinkedIn, walkthrough, next steps

## Verified project evidence

The following statements are supported by the deployment and CI evidence collected on October 7, 2026:

- AWS EKS deployment in `ap-south-1`; Jenkins main build #10 completed successfully and pushed the `orders-api` and `inventory-api` images to ECR.
- Argo CD reported the applications Synced and Healthy. Both APIs returned `{"status":"ok"}`, and each service had four available replicas.
- The good `orders-api` canary completed with four available replicas and a successful AnalysisRun.
- The platform includes Jenkins security/quality stages, GitOps deployment, Terraform infrastructure, Prometheus-based canary analysis, Kyverno policies, and an advisory LLM reviewer. Do not turn implemented capability into an unmeasured performance or security outcome.

**Still to verify:** the bad-release analysis must fail and the rollout must return to the previously stable ReplicaSet without manually restoring the manifest. The bad-release commit was pushed, but the last recorded Argo CD check still showed the prior revision. Therefore, no automatic rollback duration or completed rollback is claimed here. The dev `orders-api` failure-injection values have been restored to zero in the repository; verify Argo CD sync and the live rollout before leaving the cluster running.

Collect these before adding numerical claims:

| Metric | Evidence to collect |
|---|---|
| Pipeline duration | Jenkins build history; report the sample size and range or average |
| Bad-release rollback | Argo CD revision, failed AnalysisRun, rollout events, and stable ReplicaSet before/after |
| Scan findings | Trivy reports from the relevant build; distinguish findings from findings fixed |
| Test coverage | pytest coverage report |
| Demo cost | AWS Cost Explorer for the measured dates |
| Rebuild time | Timed clean kind run or Terraform apply-to-healthy interval |

## Resume-ready project entry

**DevSecOps Delivery Platform | Personal Project**\
*AWS EKS, Terraform, Jenkins, Docker, Amazon ECR, Argo CD, Argo Rollouts, Prometheus, Grafana, Python*

- Built a Jenkins CI/CD pipeline for two Python/FastAPI services with automated testing and security/quality tooling; a successful main-branch build published both service images to Amazon ECR.
- Deployed the services to Amazon EKS in `ap-south-1` using Terraform and Argo CD GitOps; verified healthy four-replica rollouts and a successful Prometheus-analyzed canary release.
- Added least-privilege AWS image-publishing access, Kubernetes workload and admission-policy hardening, observability dashboards/alerts, and an advisory LLM reviewer that cannot override deterministic CI gates.

Select the bullets that match the role, and remove any component you cannot explain or demonstrate in an interview. Do not add rollback, SLO, coverage, finding-count, pipeline-time, or cost metrics until you have collected the corresponding evidence. The bad-release automatic rollback is still pending end-to-end verification.

## LinkedIn summary (one paragraph)
I built an AI-assisted DevSecOps delivery platform for two Python services on Amazon EKS in `ap-south-1`. Jenkins automates CI and publishes container images to ECR using instance-profile permissions; Argo CD manages deployment from Git, and Argo Rollouts performs canary releases with Prometheus analysis. I verified healthy service rollouts and a successful canary, and added Terraform infrastructure, observability, Kyverno policies, and an advisory LLM review step that cannot bypass deterministic CI gates. Automatic rollback of a deliberately bad release is the remaining end-to-end validation. Repository: [link].

## 2-minute walkthrough script
"This project is a delivery platform for two small Python services; the platform is the point. Jenkins runs the configured test, security, and quality stages, and an LLM can provide advisory feedback but cannot make deployment decisions. On main, Jenkins builds and scans images, generates an SBOM, pushes to ECR using instance-profile permissions, and updates the GitOps repository; Jenkins does not deploy directly to Kubernetes. Argo CD applies the change and Argo Rollouts performs a canary with Prometheus analysis of error rate and latency. I verified a good release through a successful analysis and healthy four-replica rollout. The bad-release automatic rollback is still being validated, so I do not claim it as a completed demo. The project also includes Terraform-managed AWS infrastructure, observability, Kyverno policies, and Kubernetes workload hardening. The AWS demo is configured for `ap-south-1`; I use teardown steps to limit ongoing costs."

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

# 25 interview questions with project-specific answers

Use your own measured numbers where marked. Do not quote numbers you have not measured.

## CI/CD
1. **Walk me through the pipeline.** Push triggers Jenkins multibranch via webhook. Gitleaks, ruff, pytest with an 80% coverage gate, SonarQube gate, Trivy filesystem scan, image build, Trivy image scan plus an SBOM. On main only: push to ECR and commit an image-tag bump to Git. Argo CD does the deploy.
2. **Why are scans split into filesystem and image?** The filesystem scan catches dependency and config problems early and cheaply; the image scan catches OS-layer packages that only exist after the build.
3. **How does Jenkins authenticate to AWS?** The EC2 instance profile gives short-lived credentials via IMDSv2. Nothing long-lived is stored. The role can only log in to ECR and push to two repositories.
4. **Why does Jenkins commit to Git instead of running kubectl?** Git becomes the single audited source of truth, Jenkins never needs cluster credentials, and rollback is `git revert`.
5. **How do you stop the config commit from re-triggering the pipeline?** `[skip ci]` in the message with the SCM Skip plugin. A separate config repo is the cleaner production setup.
6. **What happens if SonarQube is down?** The quality gate stage fails closed. Deterministic gates fail closed; only the advisory AI step fails open.

## GitOps / Kubernetes
7. **Push vs pull deployment?** Pull (Argo CD) keeps cluster credentials inside the cluster and continuously corrects drift. Push CI needs cluster credentials and cannot see drift.
8. **What does selfHeal do and what is the catch?** It reverts manual changes to match Git. The catch: an emergency `kubectl edit` disappears, so incident fixes must go through Git or pause sync first.
9. **Explain app-of-apps.** One root Application renders a Helm chart that creates one Application per service and per platform component. Sync waves order CRD-providing components (Rollouts, Prometheus, Kyverno) before things that use their CRDs.
10. **Why a Rollout instead of a Deployment?** It adds canary steps plus metric-gated promotion and automatic abort, which Deployments cannot do.
11. **Why PDBs and HPAs?** PDB limits voluntary disruption (node drains) so capacity does not drop below safe levels; HPA scales on CPU. The HPA targets the Rollout object, and `replicas` is omitted from the Rollout when HPA is on to avoid fighting it.
12. **What is IRSA?** The EKS OIDC provider lets a ServiceAccount assume an IAM role. Each pod gets only its own permissions; External Secrets can read `/devsecops/*` and nothing else.

## Progressive delivery
13. **How does the canary decide to abort?** Background analysis queries Prometheus every 20 s for error ratio and p95 latency of canary pods. Two failures abort the rollout and traffic returns to stable.
14. **How do you measure only the canary?** The ServiceMonitor copies the `rollouts-pod-template-hash` pod label onto metrics, and the query filters on the rollout's latest hash.
15. **What if there is no traffic?** An empty query result would give a false pass or false fail. The success condition treats empty as healthy, and a loadgen deployment guarantees traffic in the demo. In production you would require a minimum request volume before trusting the result.
16. **Why 25/50/100 and not 10/50/100?** With replica-based splitting and 4 replicas, 10% is not representable. Exact weights need an ingress or mesh traffic router (documented upgrade path).

## Terraform / AWS
17. **How is state managed?** S3 backend with versioning, encryption, public access blocked, and native lockfile locking (Terraform 1.10+), so no DynamoDB table is needed.
18. **Why wrap community modules?** VPC and EKS are solved, well-tested problems; the wrapper limits the interface to what this project needs. I can explain what the modules create (subnets, route tables, NAT, OIDC provider, node groups).
19. **How do you control cost?** Budget alerts, SPOT nodes, single NAT, `make eks-down`, stopping Jenkins, and developing on kind. Measured session cost: (your Cost Explorer number).
20. **Why no SSH on the Jenkins box?** SSM Session Manager gives IAM-authenticated, logged access without an open port.

## Observability / SRE
21. **What is your SLO and how is it computed?** 99.5% availability (non-5xx) over 30 days, from `http_requests_total`. Error budget remaining = 1 - (observed error ratio / allowed error ratio).
22. **What do your alerts catch and why those?** High error rate and fast budget burn (user impact), p95 latency, crashloops, node pressure, aborted rollouts. Each links to a runbook.
23. **Golden signals in your dashboards?** Traffic, errors, latency (p95), saturation (CPU), plus rollout and Jenkins views.

## Security / AI tradeoffs
24. **How do you handle secrets?** Gitleaks in CI, nothing in Git, External Secrets pulling from SSM via IRSA, Jenkins credentials only for non-AWS tokens, Kyverno requiring non-root and limits.
25. **Why is the AI step advisory and how is it made safe?** LLM output is non-deterministic and the diff is untrusted input (prompt injection). So: it only comments; input is redacted, size-capped and wrapped in data tags; a timeout and error handling make it skip silently; output tokens are capped. Deterministic checks decide the build. Limit: a 1.5B local model gives shallow reviews, so I treat it as a convenience, not a control.

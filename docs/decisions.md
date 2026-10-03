# Decisions log (ADR style)

## 001 AI is advisory only
LLM output is non-deterministic and can be prompt-injected through the diff. It comments on PRs; it never fails, approves or promotes anything. Every error path in `ci/ai-reviewer/reviewer.py` exits 0. Untrusted text is wrapped in `<data>` tags and secrets are redacted before sending.

## 002 kind first, EKS for short demos only
EKS control plane ~$0.10/h plus NAT and nodes is not free-tier. Develop on kind, run EKS for 2-3 hour recording sessions, then `make eks-down`.

## 003 Small local model (Ollama)
No paid API, 8 GB laptop. A 1.5B-3B model is enough for summaries. Input capped at 12k chars, output at 500 tokens, 90 s timeout. EC2 Jenkins cannot reach a laptop, so the step skips unless `OLLAMA_URL` points somewhere reachable (SSH reverse tunnel or Tailscale). This is acceptable because the step is advisory.

## 004 Jenkins, not GitHub Actions
Matches existing skills and resume. The pipeline runs each tool as a pinned container so the Jenkins host stays clean and versions are reproducible.

## 005 One generic Helm chart for both services
The services differ only in image and env. One chart means one thing to test and review. Split into per-service charts when they genuinely diverge.

## 006 Canary weights by replica count (25/50/100, not 10/50/100)
Without an ingress controller or service mesh, Argo Rollouts approximates weight with replica ratios. With 4 replicas, 10% is not representable, so 25% is the smallest honest step. Upgrade path: NGINX Ingress or Gateway API traffic routing for exact weights.

## 007 Background analysis, not inline steps
The AnalysisTemplate runs for the whole rollout and aborts it on failure. Queries filter on `rollouts_pod_template_hash` so only canary pods are judged, not the stable pods that dilute the average.

## 008 Config lives in `/deploy` of the same repo
Simpler to demo than a second repo. Jenkins commits with `[skip ci]` to avoid a build loop. Trade-off: app and config history are mixed; a separate config repo is the production pattern.

## 009 Wrap community Terraform modules (VPC, EKS, IRSA)
Reinventing the VPC and EKS modules adds risk, not learning value. The wrappers keep the interface small and project-specific.

## 010 Native S3 state locking (`use_lockfile`)
Terraform >= 1.10 locks in S3 itself; DynamoDB locking is deprecated.

## 011 Kyverno policies scoped to the `apps` namespace
Cluster-wide enforcement would break system charts. Start narrow, widen deliberately.

## 012 Secrets only via External Secrets + SSM
Nothing secret in Git. Demo Grafana password is a plain value and is called out as demo-only.

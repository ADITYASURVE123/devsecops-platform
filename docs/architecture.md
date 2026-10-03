# Architecture

```mermaid
flowchart LR
  Dev[Developer: PR / push] --> GH[GitHub]
  GH -- webhook --> J[Jenkins multibranch]
  subgraph CI[Jenkins CI - pinned tool containers]
    G1[Gitleaks] --> G2[ruff + pytest + coverage] --> G3[SonarQube gate] --> G4[Trivy fs] --> B[Docker build] --> G5[Trivy image + Syft SBOM]
  end
  J --> CI
  J -. advisory, non-blocking .-> AI[Ollama: PR review / release notes / failure explainer]
  CI -- main only, instance-profile auth --> ECR[(ECR)]
  CI -- main only: image tag commit --> GH
  GH -- watched by --> Argo[Argo CD app-of-apps]
  Argo --> Roll[Argo Rollouts canary 25% -> 50% -> 100%]
  Roll <-- AnalysisTemplate: error rate, p95 --> Prom[Prometheus]
  Argo --> Plat[Kyverno, NetworkPolicy, HPA, PDB, External Secrets]
  Prom --> Graf[Grafana + SLO panels]
  Prom --> AM[Alertmanager -> Slack]
  SSM[(SSM Parameter Store)] -- IRSA --> ESO[External Secrets Operator]
```

## Trust boundaries
- Jenkins talks to AWS only through its EC2 **instance profile** (ECR push to two repos). No stored access keys.
- Jenkins never runs `kubectl`. It only edits Git; Argo CD pulls and applies.
- Cluster workloads get AWS access through **IRSA** (pod-level roles), not node roles.
- The LLM sees a redacted, size-capped diff and can only write a comment.

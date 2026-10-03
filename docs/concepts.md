# Concepts from zero (one analogy each)

**Helm** is a mail-merge for Kubernetes YAML. One template plus a values file produces the final manifests. `values.yaml` holds defaults; `deploy/envs/<env>/<svc>.yaml` overrides them.

**Argo CD (GitOps)** is a building inspector who keeps comparing the real building to the blueprint (Git) and fixes any drift. `selfHeal` undoes manual changes; `prune` removes things deleted from Git. **App-of-apps** is one blueprint listing all the other blueprints.

**Argo Rollouts** is a restaurant tasting a new dish on two tables before serving everyone. A `Rollout` replaces `Deployment`; it shifts a bit of traffic to the new version, pauses, checks the metrics, then continues or aborts.

**AnalysisTemplate** is the taste-test scorecard: Prometheus queries plus a pass condition (error rate < 5%, p95 < 500 ms). Two failed checks abort the rollout.

**Prometheus** is a clipboard-carrying inspector who visits every service every 15 s and writes down its numbers. **PromQL** is how you ask the clipboard questions. **Alerting rules** are "tap me on the shoulder if this number stays bad for N minutes". **Alertmanager** decides who gets tapped and groups duplicates.

**SLO / error budget:** an SLO of 99.5% means 0.5% of requests may fail. That 0.5% is a budget you spend on risk (releases). Burn it too fast and you slow down releases.

**Kyverno** is the club bouncer: pods that break the house rules (`:latest`, no limits, root user, missing labels) are refused at the door.

**NetworkPolicy** is door locks between rooms: default-deny, then open only the doors needed. (kind's default CNI does not enforce them; EKS with the VPC CNI setting does.)

**IRSA** gives each pod its own badge from AWS instead of a master key on the node.

**External Secrets** is a courier fetching secrets from SSM at runtime so Git never contains them.

**SBOM (Syft)** is the ingredients label of an image; **Trivy** checks the label against known-bad ingredients; **Gitleaks** looks for passwords written on sticky notes in the repo.

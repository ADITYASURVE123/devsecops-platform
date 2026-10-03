# Runbook: high latency
**Alerts:** `HighLatencyP95`, `NodePressure`
**Triage order:** (1) did a rollout just happen? (2) CPU saturation panel / HPA at max? (3) node memory/disk pressure? (4) downstream dependency?
**Commands:** `kubectl -n apps top pods`; `kubectl get hpa -n apps`; `kubectl describe node <node> | grep -A5 Conditions`
**Fix paths:** raise HPA max or resource limits via Git; if tied to a release, abort/revert; if node pressure, add capacity or fix the noisy pod.
**Verify:** p95 under 500 ms for 10 minutes.

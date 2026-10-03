# Runbook: bad deploy
**Alerts:** `HighErrorRate`, `ErrorBudgetFastBurn`, `RolloutAborted`
**Detect:** Grafana > Services dashboard (5xx ratio); `kubectl argo rollouts get rollout <svc> -n apps`
**Expected automatic behavior:** canary analysis fails 2 checks -> rollout aborts -> stable ReplicaSet keeps serving.
**Verify rollback:** status `Degraded`, canary ReplicaSet scaled to 0, 5xx ratio returns to baseline.
**If it did NOT auto-abort:** `kubectl argo rollouts abort <svc> -n apps`, then `git revert` the image-tag commit so Git matches reality (Argo self-heal would otherwise re-apply it).
**After:** write down cause, time-to-detect, time-to-rollback; check whether error budget was consumed.

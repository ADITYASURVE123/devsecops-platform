# Runbook: pod crashloop
**Alert:** `PodCrashLooping` (>3 restarts in 10m)
**Triage:** `kubectl -n apps describe pod <pod>` (events, last state, exit code); `kubectl -n apps logs <pod> --previous`
**Common causes:** bad env/config (check the last Git commit in `deploy/envs`), OOMKilled (raise memory limit in values), failing liveness probe, image pull error.
**Fix:** change values in Git, never `kubectl edit` (self-heal reverts it). If a rollout is in progress it will already be paused/aborted.
**Verify:** restarts stop, readiness green, alert resolves.

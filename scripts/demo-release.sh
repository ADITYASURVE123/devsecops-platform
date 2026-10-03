#!/usr/bin/env bash
# Usage: demo-release.sh good|bad <service> [env]
# good = bumps a harmless env var -> new ReplicaSet, canary passes analysis, promotes to 100%
# bad  = injects 40% 5xx + 700ms latency -> analysis fails, Argo Rollouts aborts and rolls back
set -euo pipefail
kind_="${1:?good|bad}"; svc="${2:?service}"; env="${3:-dev}"
file="deploy/envs/${env}/${svc}.yaml"
stamp="$(date +%s)"
case "$kind_" in
  good) err="0";   lat="0";   ;;
  bad)  err="0.4"; lat="700"; ;;
  *) echo "use good|bad" >&2; exit 1 ;;
esac
python3 - "$file" "$err" "$lat" "$stamp" <<'PY'
import sys, re
f, err, lat, stamp = sys.argv[1:]
s = open(f).read()
s = re.sub(r'(ERROR_RATE: )"[^"]*"', rf'\1"{err}"', s)
s = re.sub(r'(LATENCY_MS: )"[^"]*"', rf'\1"{lat}"', s)
if "RELEASE_STAMP" in s:
    s = re.sub(r'(RELEASE_STAMP: )"[^"]*"', rf'\1"{stamp}"', s)
else:
    s = s.replace("env:\n", f'env:\n  RELEASE_STAMP: "{stamp}"\n', 1)
open(f, "w").write(s)
PY
git add "$file" && git commit -m "demo: ${kind_} release of ${svc}" && git push
echo "Watch it:  kubectl argo rollouts get rollout ${svc} -n apps -w"

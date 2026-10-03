#!/usr/bin/env bash
# Usage: [ECR_REGISTRY=<host>] bump-image-tag.sh <service> <tag> [env]
# Edits deploy/envs/<env>/<service>.yaml; commit + push is done by the Jenkinsfile.
set -euo pipefail
svc="${1:?service}"; tag="${2:?tag}"; env="${3:-dev}"
file="deploy/envs/${env}/${svc}.yaml"
[[ -f "$file" ]] || { echo "missing $file" >&2; exit 1; }
[[ "$tag" != "latest" ]] || { echo "refusing :latest" >&2; exit 1; }
sed -i -E "s|^(  tag: ).*|\1\"${tag}\"|" "$file"
if [[ -n "${ECR_REGISTRY:-}" ]]; then
  sed -i -E "s|^(  repository: ).*|\1\"${ECR_REGISTRY}/${svc}\"|" "$file"
fi
grep -nE "repository:|tag:" "$file"

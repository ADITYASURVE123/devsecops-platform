{{/* One Argo CD Application for an upstream Helm chart. Values live in THIS repo (multi-source). */}}
{{- define "helmapp" -}}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ .name }}
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: {{ .wave | quote }}
spec:
  project: default
  sources:
    - repoURL: {{ .chartRepo }}
      chart: {{ .chart }}
      targetRevision: {{ .version | quote }}
      helm:
        releaseName: {{ .name }}
        valueFiles:
          - {{ .valuesFile | quote }}
        {{- if .extraValues }}
        valuesObject: {{ .extraValues | toJson }}
        {{- end }}
    - repoURL: {{ .repoURL }}
      targetRevision: {{ .rev }}
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: {{ .ns }}
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [CreateNamespace=true, ServerSideApply=true]
    retry: { limit: 10, backoff: { duration: 15s, factor: 2, maxDuration: 5m } }
{{- end -}}

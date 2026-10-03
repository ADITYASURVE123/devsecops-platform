{{- define "svc.labels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/part-of: devsecops-platform
{{- end -}}

{{- define "local-postgresql.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "local-postgresql.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "local-postgresql.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "local-postgresql.labels" -}}
app.kubernetes.io/name: {{ include "local-postgresql.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}


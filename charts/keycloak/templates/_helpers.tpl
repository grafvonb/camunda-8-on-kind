{{- define "local-keycloak.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "local-keycloak.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "local-keycloak.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "local-keycloak.labels" -}}
app.kubernetes.io/name: {{ include "local-keycloak.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}


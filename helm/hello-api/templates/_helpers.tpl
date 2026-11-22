{{- define "hello-api.labels" -}}
app.kubernetes.io/name: hello-api
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- define "hello-api.selectorLabels" -}}
app.kubernetes.io/name: hello-api
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

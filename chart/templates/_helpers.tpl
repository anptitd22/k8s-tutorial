{{/*
Expand the name of the chart.
*/}}
{{- define "chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chart.labels" -}}
helm.sh/chart: {{ include "chart.chart" . }}
{{ include "chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Mongo fullname
*/}}
{{- define "chart.mongo.fullname" -}}
{{- if .Values.mongo.fullnameOverride }}
{{- .Values.mongo.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-mongo" (include "chart.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Mongo service name
*/}}
{{- define "chart.mongo.serviceName" -}}
{{- default (include "chart.mongo.fullname" .) .Values.mongo.service.name }}
{{- end }}

{{/*
Mongo labels
*/}}
{{- define "chart.mongo.labels" -}}
helm.sh/chart: {{ include "chart.chart" . }}
{{ include "chart.mongo.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Mongo selector labels
*/}}
{{- define "chart.mongo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chart.name" . }}-mongo
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ .Values.mongo.name | default "mongo" }}
{{- end }}

{{/*
Mongo Express fullname
*/}}
{{- define "chart.mongoExpress.fullname" -}}
{{- if .Values.mongoExpress.fullnameOverride }}
{{- .Values.mongoExpress.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-mongo-express" (include "chart.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Mongo Express service name
*/}}
{{- define "chart.mongoExpress.serviceName" -}}
{{- default (include "chart.mongoExpress.fullname" .) .Values.mongoExpress.service.name }}
{{- end }}

{{/*
Mongo Express labels
*/}}
{{- define "chart.mongoExpress.labels" -}}
helm.sh/chart: {{ include "chart.chart" . }}
{{ include "chart.mongoExpress.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Mongo Express selector labels
*/}}
{{- define "chart.mongoExpress.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chart.name" . }}-mongo-express
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ .Values.mongoExpress.name | default "mongo-express" }}
{{- end }}

{{/*
Secret name
*/}}
{{- define "chart.secretName" -}}
{{- if .Values.secret.existingSecret }}
{{- .Values.secret.existingSecret }}
{{- else }}
{{- default (printf "%s-secret" (include "chart.fullname" .)) .Values.secret.name }}
{{- end }}
{{- end }}

{{/*
ConfigMap name
*/}}
{{- define "chart.configMapName" -}}
{{- default (printf "%s-configmap" (include "chart.fullname" .)) .Values.configMap.name }}
{{- end }}

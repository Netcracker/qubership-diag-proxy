{{/*
Find a diag-proxy image in various places.
Image can be found from:
* specified by user from .Values.IMAGE_REPOSITORY and .Values.TAG
* default value
*/}}
{{- define "diag-proxy.image" -}}
  {{- if and (not (empty .Values.IMAGE_REPOSITORY)) (not (empty .Values.TAG)) -}}
    {{- printf "%s:%s" .Values.IMAGE_REPOSITORY .Values.TAG -}}
  {{- else -}}
    {{- printf "ghcr.io/netcracker/diag-proxy:main" -}}
  {{- end -}}
{{- end -}}
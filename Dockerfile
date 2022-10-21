# syntax=docker/dockerfile:latest
ARG ALPINE_VERSION=3.16
FROM alpine:${ALPINE_VERSION}
SHELL [ "/bin/sh", "-cx" ]
ARG GOCRON_VERESION=0.0.5
ARG TARGETARCH
COPY --from=minio/mc /bin/mc /usr/local/bin/mc
RUN --mount=type=cache,target=/tmp/ <<EOF
apk add --update --cache-dir /tmp/ postgresql14-client bash jq
apk add -X http://dl-cdn.alpinelinux.org/alpine/edge/main zstd
wget -O - https://github.com/ivoronin/go-cron/releases/download/v${GOCRON_VERESION}/go-cron_${GOCRON_VERESION}_linux_${TARGETARCH}.tar.gz \
  | tar -xvzf - go-cron -C /usr/local/bin/
EOF
COPY src/ /
ENTRYPOINT [ "/run.sh" ]

# syntax=docker/dockerfile:1
FROM ubuntu:24.04
SHELL [ "/bin/bash", "-cx" ]
COPY --from=minio/mc /bin/mc /usr/local/bin/mc
RUN <<EOF
apt update
apt install -y --no-install-recommends postgresql-client-16 jq zstd
apt clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF
COPY --link src/ /bin/
ENTRYPOINT [ "run.sh" ]

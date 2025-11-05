# syntax=docker/dockerfile:1
FROM ubuntu
SHELL [ "/bin/bash", "-cx" ]
COPY --from=minio/mc /bin/mc /usr/local/bin/mc
RUN <<EOF
apt update
apt install -y --no-install-recommends jq zstd ca-certificates curl gnupg
apt clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
curl -L -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl
kubectl version --client=true
EOF
COPY --link src/ /bin/
RUN ln -s /bin/backup.sh /backup.sh
ENTRYPOINT [ "/bin/run.sh" ]

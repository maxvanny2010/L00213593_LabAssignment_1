#!/bin/bash
set -euxo pipefail

dnf install -y docker

systemctl enable --now docker

systemctl is-active --quiet docker

docker info >/dev/null
docker --version
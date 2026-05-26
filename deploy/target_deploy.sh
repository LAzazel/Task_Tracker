#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/mywebapp"
IMAGE_NAME=${IMAGE_NAME:-"ghcr.io/owner/repo"}
IMAGE_TAG=${IMAGE_TAG:-"stable"}
GHCR_USER=${GHCR_USER:-""}
GHCR_TOKEN=${GHCR_TOKEN:-""}

if [[ -z "${GHCR_USER}" || -z "${GHCR_TOKEN}" ]]; then
  echo "Missing GHCR credentials" >&2
  exit 1
fi

mkdir -p "${APP_DIR}"
cd "${APP_DIR}"

echo "IMAGE_NAME=${IMAGE_NAME}" > .env
echo "IMAGE_TAG=${IMAGE_TAG}" >> .env

echo "Logging in to GHCR"
echo "${GHCR_TOKEN}" | docker login ghcr.io -u "${GHCR_USER}" --password-stdin

docker pull "${IMAGE_NAME}:${IMAGE_TAG}"

systemctl start mywebapp-container.service || true
systemctl restart mywebapp-container.service

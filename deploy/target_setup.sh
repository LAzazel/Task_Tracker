#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/mywebapp"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

apt-get update
apt-get install -y docker.io docker-compose-plugin
systemctl enable --now docker

mkdir -p "${APP_DIR}"
install -m 644 "${APP_DIR}/docker-compose.prod.yml" "${APP_DIR}/docker-compose.prod.yml" 2>/dev/null || true

# Copy config files from current directory when executed manually
if [[ -f "./docker-compose.prod.yml" ]]; then
  install -m 644 ./docker-compose.prod.yml "${APP_DIR}/docker-compose.prod.yml"
fi
if [[ -f "./nginx.conf" ]]; then
  install -m 644 ./nginx.conf "${APP_DIR}/nginx.conf"
fi
if [[ -f "./config.ini" ]]; then
  install -m 644 ./config.ini "${APP_DIR}/config.ini"
fi

install -m 644 /opt/mywebapp/mywebapp-container.service /etc/systemd/system/mywebapp-container.service 2>/dev/null || true
if [[ -f "./mywebapp-container.service" ]]; then
  install -m 644 ./mywebapp-container.service /etc/systemd/system/mywebapp-container.service
fi

systemctl daemon-reload
systemctl enable mywebapp-container.service

echo "Target node prepared"

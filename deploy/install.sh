#!/usr/bin/env bash
set -euo pipefail

APP_NAME="mywebapp"
APP_DIR="/opt/${APP_NAME}"
CONFIG_DIR="/etc/${APP_NAME}"
CONFIG_FILE="${CONFIG_DIR}/config.ini"
DB_NAME="mywebapp"
DB_USER="mywebapp"
DB_PASS="mywebapp_pass"
DEFAULT_USER="ubuntu"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

apt-get update
apt-get install -y python3 python3-venv python3-pip nginx postgresql rsync

id -u student >/dev/null 2>&1 || useradd -m -s /bin/bash student
id -u teacher >/dev/null 2>&1 || useradd -m -s /bin/bash teacher
if ! id -u operator >/dev/null 2>&1; then
  getent group operator >/dev/null 2>&1 || groupadd operator
  useradd -m -s /bin/bash -g operator operator
fi

if ! id -u app >/dev/null 2>&1; then
  getent group app >/dev/null 2>&1 || groupadd app
  useradd -r -s /usr/sbin/nologin -g app app
fi

for user in student teacher operator; do
  echo "${user}:12345678" | chpasswd
  chage -d 0 "${user}"
done

usermod -aG sudo student
usermod -aG sudo teacher

if id -u "${DEFAULT_USER}" >/dev/null 2>&1; then
  usermod --lock "${DEFAULT_USER}"
fi

mkdir -p "${CONFIG_DIR}"
cat > "${CONFIG_FILE}" <<EOF
[app]
host = 127.0.0.1
port = 5000

[db]
host = 127.0.0.1
port = 5432
name = ${DB_NAME}
user = ${DB_USER}
password = ${DB_PASS}
EOF

chown root:app "${CONFIG_FILE}"
chmod 640 "${CONFIG_FILE}"

mkdir -p /home/student
printf "19" > /home/student/gradebook
chown student:student /home/student/gradebook
chmod 600 /home/student/gradebook

sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"

sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

PG_CONF="/etc/postgresql"
PG_VERSION=$(ls "$PG_CONF")
PG_MAIN="${PG_CONF}/${PG_VERSION}/main"

sed -i "s/^#\?listen_addresses.*/listen_addresses = '127.0.0.1'/" "${PG_MAIN}/postgresql.conf"

if ! grep -q "^host\s\+all\s\+all\s\+127.0.0.1/32" "${PG_MAIN}/pg_hba.conf"; then
  echo "host all all 127.0.0.1/32 scram-sha-256" >> "${PG_MAIN}/pg_hba.conf"
fi

systemctl restart postgresql

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}"
rsync -a --delete ./ "${APP_DIR}/"
chown -R app:app "${APP_DIR}"

python3 -m venv "${APP_DIR}/venv"
"${APP_DIR}/venv/bin/pip" install -r "${APP_DIR}/requirements.txt"

install -m 644 "${APP_DIR}/deploy/systemd/mywebapp.service" /etc/systemd/system/mywebapp.service
install -m 644 "${APP_DIR}/deploy/systemd/mywebapp.socket" /etc/systemd/system/mywebapp.socket

systemctl daemon-reload
systemctl enable --now mywebapp.socket
systemctl reset-failed mywebapp.service mywebapp.socket
systemctl restart mywebapp.socket

install -m 644 "${APP_DIR}/deploy/nginx/mywebapp.conf" /etc/nginx/sites-available/mywebapp.conf
ln -sf /etc/nginx/sites-available/mywebapp.conf /etc/nginx/sites-enabled/mywebapp.conf
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl reload nginx

cat > /etc/sudoers.d/operator <<'EOF'
operator ALL=NOPASSWD: /bin/systemctl start mywebapp, /bin/systemctl stop mywebapp, /bin/systemctl restart mywebapp, /bin/systemctl status mywebapp, /bin/systemctl reload nginx
EOF
chmod 440 /etc/sudoers.d/operator

systemctl restart mywebapp.socket

echo "Done"

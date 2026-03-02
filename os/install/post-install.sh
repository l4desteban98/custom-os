#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/abacus-appliance"
INSTALL_DIR="$APP_DIR/os/install"
SCRIPTS_DIR="$APP_DIR/scripts"
SPECS_DIR="$APP_DIR/specs"
CERTS_DIR="$APP_DIR/certs"
NGINX_DIR="$APP_DIR/nginx"
HOSTNAME_VALUE="lerix-llm"

hostnamectl set-hostname "$HOSTNAME_VALUE"

apt-get update
apt-get install -y avahi-daemon libnss-mdns openssl

mkdir -p "$SCRIPTS_DIR" "$SPECS_DIR" "$CERTS_DIR" "$NGINX_DIR"

if [[ -f "$APP_DIR/os/scripts/motd.py" ]]; then
  install -m 0755 "$APP_DIR/os/scripts/motd.py" "$SCRIPTS_DIR/motd.py"
fi

install -m 0755 "$INSTALL_DIR/generate-specs-json.sh" /usr/local/bin/generate-specs-json.sh
install -m 0644 "$INSTALL_DIR/specs-api.service" /etc/systemd/system/specs-api.service
install -m 0644 "$INSTALL_DIR/nginx-default.conf" "$NGINX_DIR/default.conf"
install -m 0644 "$INSTALL_DIR/llm-https.service" /etc/avahi/services/llm-https.service
install -m 0755 "$INSTALL_DIR/gpu-docker-info.sh" /etc/profile.d/90-gpu-docker-info.sh

openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
  -keyout "$CERTS_DIR/tls.key" \
  -out "$CERTS_DIR/tls.crt" \
  -subj "/CN=lerix-llm.local" \
  -addext "subjectAltName=DNS:lerix-llm.local,DNS:lerix-llm"

systemctl enable docker.service containerd.service
systemctl restart docker.service

if lspci | grep -qi nvidia; then
  ubuntu-drivers install || true
fi

systemctl daemon-reload
systemctl enable specs-api.service
systemctl enable avahi-daemon.service
systemctl restart avahi-daemon.service

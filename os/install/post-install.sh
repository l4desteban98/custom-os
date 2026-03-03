#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/abacus-appliance"
INSTALL_DIR="$APP_DIR/os/install"
SCRIPTS_DIR="$APP_DIR/scripts"
SELFTEST_DIR="$APP_DIR/selftest"
SPECS_DIR="$APP_DIR/specs"
CERTS_DIR="$APP_DIR/certs"
NGINX_DIR="$APP_DIR/nginx"
HOSTNAME_VALUE="lerix-llm"

hostnamectl set-hostname "$HOSTNAME_VALUE"

apt-get update
apt-get install -y avahi-daemon libnss-mdns openssl python3-venv python3-pip

mkdir -p "$SCRIPTS_DIR" "$SELFTEST_DIR" "$SPECS_DIR" "$CERTS_DIR" "$NGINX_DIR"
mkdir -p /etc/abacus-appliance/tls /var/lib/abacus-llm /var/log/abacus-appliance
chmod 700 /etc/abacus-appliance

if [[ -f "$APP_DIR/os/scripts/motd.py" ]]; then
  install -m 0755 "$APP_DIR/os/scripts/motd.py" "$SCRIPTS_DIR/motd.py"
fi

if [[ -f "$APP_DIR/os/scripts/healthcheck.py" ]]; then
  install -m 0755 "$APP_DIR/os/scripts/healthcheck.py" "$SCRIPTS_DIR/healthcheck.py"
fi

install -m 0755 "$INSTALL_DIR/generate-specs-json.sh" /usr/local/bin/generate-specs-json.sh
install -m 0755 "$INSTALL_DIR/gpu-docker-info.sh" /etc/profile.d/90-gpu-docker-info.sh
install -m 0644 "$INSTALL_DIR/nginx-default.conf" "$NGINX_DIR/default.conf"
install -m 0644 "$INSTALL_DIR/llm-https.service" /etc/avahi/services/llm-https.service
install -m 0644 "$INSTALL_DIR/avahi-daemon.conf" /etc/avahi/avahi-daemon.conf

install -m 0644 "$APP_DIR/os/compose/docker-compose.prod.yml" "$APP_DIR/docker-compose.prod.yml"

install -m 0644 "$APP_DIR/os/selftest/specs.yaml" "$SELFTEST_DIR/specs.yaml"
install -m 0644 "$APP_DIR/os/selftest/requirements.txt" "$SELFTEST_DIR/requirements.txt"
install -m 0644 "$APP_DIR/os/selftest/test_selftest.py" "$SELFTEST_DIR/test_selftest.py"
install -m 0755 "$APP_DIR/os/selftest/run_selftest.sh" "$SELFTEST_DIR/run_selftest.sh"

if [[ ! -x /opt/abacus-appliance/.venv-selftest/bin/python ]]; then
  python3 -m venv /opt/abacus-appliance/.venv-selftest
  /opt/abacus-appliance/.venv-selftest/bin/pip install --upgrade pip
  /opt/abacus-appliance/.venv-selftest/bin/pip install -r "$SELFTEST_DIR/requirements.txt"
fi

if [[ ! -f /etc/abacus-appliance/specs.yaml ]]; then
  install -m 0644 "$APP_DIR/os/selftest/specs.yaml" /etc/abacus-appliance/specs.yaml
fi

install -m 0644 "$APP_DIR/os/systemd/abacus-init.service" /etc/systemd/system/abacus-init.service
install -m 0644 "$APP_DIR/os/systemd/abacus-selftest.service" /etc/systemd/system/abacus-selftest.service
install -m 0644 "$APP_DIR/os/systemd/abacus-stack.service" /etc/systemd/system/abacus-stack.service
install -m 0644 "$APP_DIR/os/systemd/abacus-health.service" /etc/systemd/system/abacus-health.service

openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
  -keyout "$CERTS_DIR/tls.key" \
  -out "$CERTS_DIR/tls.crt" \
  -subj "/CN=lerix-llm.local" \
  -addext "subjectAltName=DNS:lerix-llm.local,DNS:lerix-llm"

if [[ ! -f /etc/abacus-appliance/tls/device.key ]]; then
  openssl req -x509 -nodes -newkey rsa:4096 \
    -keyout /etc/abacus-appliance/tls/device.key \
    -out /etc/abacus-appliance/tls/device.crt \
    -subj "/CN=lerix-llm.local" -days 3650
fi
chmod 600 /etc/abacus-appliance/tls/device.key
chmod 644 /etc/abacus-appliance/tls/device.crt

if [[ ! -f /etc/abacus-appliance/secrets.env ]]; then
  printf 'ABACUS_API_KEY=change-me\n' > /etc/abacus-appliance/secrets.env
  chmod 600 /etc/abacus-appliance/secrets.env
fi

systemctl enable docker.service containerd.service
systemctl restart docker.service

if lspci | grep -qi nvidia; then
  ubuntu-drivers install || true
fi

systemctl daemon-reload
systemctl enable avahi-daemon.service
systemctl restart avahi-daemon.service
systemctl enable abacus-init.service
systemctl enable abacus-selftest.service
systemctl enable abacus-stack.service
systemctl enable abacus-health.service

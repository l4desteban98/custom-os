#!/usr/bin/env bash
[ -t 1 ] || return 0

if [ -x /opt/abacus-appliance/scripts/motd.py ]; then
  /usr/bin/python3 /opt/abacus-appliance/scripts/motd.py || true
  return 0
fi

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
  gpu_msg="NVIDIA GPU detected"
else
  gpu_msg="NVIDIA GPU not detected"
fi

if systemctl is-active --quiet docker; then
  docker_msg="Docker service: active"
else
  docker_msg="Docker service: inactive"
fi

printf '\n[INFO] %s | %s\n\n' "$gpu_msg" "$docker_msg"

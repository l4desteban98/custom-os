#!/usr/bin/env bash
set -euo pipefail

out="/opt/abacus-appliance/specs/index.json"
hostname="$(hostname)"
kernel="$(uname -r)"
cpu="$(lscpu | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
ram_gb="$(awk '/MemTotal/ {printf "%.2f", $2/1024/1024}' /proc/meminfo)"
disk_lines="$(lsblk -dn -o NAME,SIZE,MODEL | sed 's/"/\\"/g' | awk '{printf "{\"name\":\"%s\",\"size\":\"%s\",\"model\":\"", $1, $2; for(i=3;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":""); print "\"}"}' | paste -sd, -)"

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
  gpu="$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1 | sed 's/"/\\"/g')"
else
  gpu="not-detected"
fi

docker_state="inactive"
if systemctl is-active --quiet docker; then
  docker_state="active"
fi

cat > "$out" <<JSON
{
  "hostname": "$hostname",
  "kernel": "$kernel",
  "cpu": "$cpu",
  "ram_gb": "$ram_gb",
  "gpu": "$gpu",
  "docker": "$docker_state",
  "disks": [${disk_lines:-}]
}
JSON

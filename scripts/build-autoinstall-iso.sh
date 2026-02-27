#!/usr/bin/env bash
set -euo pipefail

ISO_IN="${1:-}"
ISO_OUT="${2:-ubuntu-lerix-autoinstall.iso}"
USER_DATA="${3:-autoinstall/user-data.yaml}"
META_DATA="${4:-autoinstall/meta-data}"
WORKDIR="${WORKDIR:-./.build-iso}"

if [[ -z "$ISO_IN" ]]; then
  echo "Usage: $0 <ubuntu-live-server.iso> [output.iso] [user-data.yaml] [meta-data]"
  exit 1
fi

for cmd in xorriso awk md5sum; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    exit 1
  fi
done

if [[ ! -f "$ISO_IN" ]]; then
  echo "Input ISO not found: $ISO_IN"
  exit 1
fi

if [[ ! -f "$USER_DATA" ]]; then
  echo "user-data not found: $USER_DATA"
  exit 1
fi

if [[ ! -f "$META_DATA" ]]; then
  echo "meta-data not found: $META_DATA"
  exit 1
fi

sed_inplace() {
  local expr="$1"
  local file="$2"
  if sed --version >/dev/null 2>&1; then
    sed -i -E "$expr" "$file"
  else
    sed -i '' -E "$expr" "$file"
  fi
}

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR/iso/nocloud"

echo "[*] Extracting ISO: $ISO_IN"
xorriso -osirrox on -indev "$ISO_IN" -extract / "$WORKDIR/iso" >/dev/null 2>&1

echo "[*] Injecting NoCloud seed"
cp "$USER_DATA" "$WORKDIR/iso/nocloud/user-data"
cp "$META_DATA" "$WORKDIR/iso/nocloud/meta-data"

for cfg in "$WORKDIR/iso/boot/grub/grub.cfg" "$WORKDIR/iso/isolinux/txt.cfg"; do
  if [[ -f "$cfg" ]]; then
    echo "[*] Patching boot args in $cfg"
    sed_inplace 's@---@ autoinstall ds=nocloud\\;s=/cdrom/nocloud/ ---@g' "$cfg"
  fi
done

if [[ -f "$WORKDIR/iso/md5sum.txt" ]]; then
  echo "[*] Rebuilding md5sum.txt"
  (
    cd "$WORKDIR/iso"
    find . -type f ! -name 'md5sum.txt' -print0 | xargs -0 md5sum > md5sum.txt
  )
fi

echo "[*] Building output ISO: $ISO_OUT"
xorriso \
  -indev "$ISO_IN" \
  -outdev "$ISO_OUT" \
  -map "$WORKDIR/iso" / \
  -boot_image any replay \
  -volid "UBUNTU_LERIX_AUTOINSTALL" \
  >/dev/null 2>&1

echo "[OK] ISO created: $ISO_OUT"

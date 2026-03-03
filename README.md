# Ubuntu custom ISO (autoinstall + Docker + NVIDIA login info)

Este proyecto crea una ISO autoinstall de Ubuntu Server que:
- instala usuario `lerix` con password `1234`
- habilita SSH con login por password
- instala y habilita Docker
- detecta NVIDIA en post-install e intenta instalar drivers con `ubuntu-drivers`
- muestra en cada login un mensaje con estado de NVIDIA y Docker
- si existe `os/scripts/motd.py`, lo instala y lo usa como MOTD en login
- anuncia `lerix-llm.local` por mDNS (Avahi)
- levanta un contenedor `nginx` al arranque que expone specs del host en `https://lerix-llm.local/`
- fuerza en post-install: hostname `lerix-llm` + instalación/habilitación de `avahi-daemon`
- ejecuta self-test con `testinfra` usando `specs.yaml`; si falla, no arranca `docker compose`

## Estructura ordenada
La lógica de post-instalación ya no está embebida en `user-data.yaml`; ahora vive en archivos:
- `/Users/lerix/Projects/sandbox/custom-os/os/install/post-install.sh`
- `/Users/lerix/Projects/sandbox/custom-os/os/install/generate-specs-json.sh`
- `/Users/lerix/Projects/sandbox/custom-os/os/install/nginx-default.conf`
- `/Users/lerix/Projects/sandbox/custom-os/os/install/llm-https.service`
- `/Users/lerix/Projects/sandbox/custom-os/os/install/avahi-daemon.conf`
- `/Users/lerix/Projects/sandbox/custom-os/os/install/gpu-docker-info.sh`
- `/Users/lerix/Projects/sandbox/custom-os/os/selftest/specs.yaml`
- `/Users/lerix/Projects/sandbox/custom-os/os/selftest/test_selftest.py`
- `/Users/lerix/Projects/sandbox/custom-os/os/selftest/run_selftest.sh`
- `/Users/lerix/Projects/sandbox/custom-os/os/systemd/abacus-selftest.service`
- `/Users/lerix/Projects/sandbox/custom-os/os/systemd/abacus-stack.service`
- `/Users/lerix/Projects/sandbox/custom-os/os/compose/docker-compose.prod.yml`

`autoinstall/user-data.yaml` solo copia `os/` desde NoCloud y ejecuta `post-install.sh`.

El post-install también aplica `/etc/avahi/avahi-daemon.conf` para que `lerix-llm.local` salga anunciando mDNS desde el primer boot.

## Storage
La instalación usa `storage.layout.name: direct` para que Subiquity cree automáticamente la partición de boot correcta según el modo real (UEFI/BIOS) del equipo.

## Requisitos
- `xorriso`
- `md5sum`
- ISO oficial Ubuntu Server live (`ubuntu-24.04-live-server-amd64.iso` o similar)
- (Opcional) `packer`

macOS:
```bash
brew install xorriso packer
```

Ubuntu:
```bash
sudo apt-get update
sudo apt-get install -y xorriso packer
```

## Build rápido (sin packer)
```bash
cd /Users/lerix/Projects/sandbox/custom-os
bash scripts/build-autoinstall-iso.sh /ruta/a/ubuntu-live-server.iso ubuntu-lerix-autoinstall.iso
```

## Build con packer
```bash
cd /Users/lerix/Projects/sandbox/custom-os/packer
packer build -var 'source_iso=/ruta/a/ubuntu-live-server.iso' .
```

## Instalación
1. Flashea la ISO a USB.
2. Arranca el PC en modo UEFI desde ese USB.
3. El autoinstall corre solo y reinicia.
4. Login con `lerix / 1234`.

## Verificación
```bash
systemctl status docker --no-pager
systemctl status abacus-selftest --no-pager
systemctl status abacus-stack --no-pager
nvidia-smi
systemctl status avahi-daemon --no-pager
curl -sk https://127.0.0.1/
curl -sk https://lerix-llm.local/
sudo cat /etc/abacus-appliance/specs.yaml
```

Nota: el certificado TLS es autofirmado para uso local, así que el navegador mostrará advertencia a menos que confíes ese cert.

En cada login interactivo verás:
- `NVIDIA GPU detected` o `NVIDIA GPU not detected`
- `Docker service: active` o `inactive`

## MAAS
Si luego quieres usar MAAS, reutiliza el mismo `autoinstall/user-data.yaml` como base de cloud-init/autoinstall y mantén el mismo bloque `storage` para evitar el problema de `matched no disk`.

## HCL (packer legacy) para copiar `os/`
Si tienes un template packer con builder `qemu` + communicator SSH, usa rutas con `${path.root}`:

```hcl
provisioner "file" {
  source      = "${path.root}/../os/"
  destination = "/tmp/os"
}

provisioner "shell" {
  inline = [
    "sudo mkdir -p /opt/abacus-appliance/scripts",
    "sudo cp /tmp/os/scripts/motd.py /opt/abacus-appliance/scripts/motd.py",
    "sudo chmod 0755 /opt/abacus-appliance/scripts/motd.py",
    "printf '%s\\n' '#!/usr/bin/env bash' 'test -t 1 || exit 0' '/usr/bin/python3 /opt/abacus-appliance/scripts/motd.py || true' | sudo tee /etc/profile.d/00-abacus-motd.sh >/dev/null",
    "sudo chmod 0755 /etc/profile.d/00-abacus-motd.sh"
  ]
}
```

Nota: esto no aplica a `source \"null\"` con `communicator = \"none\"`; ahí solo corre `shell-local`.

# Ubuntu custom ISO (autoinstall + Docker + NVIDIA login info)

Este proyecto crea una ISO autoinstall de Ubuntu Server que:
- instala usuario `lerix` con password `1234`
- habilita SSH con login por password
- instala y habilita Docker
- detecta NVIDIA en post-install e intenta instalar drivers con `ubuntu-drivers`
- muestra en cada login un mensaje con estado de NVIDIA y Docker

## Sobre el error que viste en físico
Esta configuración evita `path: /dev/sda` y usa `match` en storage (`ssd: true`, `size: largest`) para no romper cuando el disco cambia a `nvme0n1` u otro nombre.

## Particiones incluidas
- `EFI`: 512M (`/boot/efi`)
- `root`: 60G (`/`)
- `docker`: 60G (`/var/lib/docker`)
- `data`: resto del disco (`/data`)

Nota: pediste `60 + 60 + 100`, pero eso no cabe en un SSD de 200GB. Esta versión está ajustada para que sí instale en ese tamaño.

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
packer init .
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
nvidia-smi
```

En cada login interactivo verás:
- `NVIDIA GPU detected` o `NVIDIA GPU not detected`
- `Docker service: active` o `inactive`

## MAAS
Si luego quieres usar MAAS, reutiliza el mismo `autoinstall/user-data.yaml` como base de cloud-init/autoinstall y mantén el mismo bloque `storage` para evitar el problema de `matched no disk`.

packer {
  required_plugins {
    null = {
      source  = "github.com/hashicorp/null"
      version = ">= 1.0.0"
    }
  }
}

variable "source_iso" {
  type = string
}

variable "output_iso" {
  type    = string
  default = "ubuntu-lerix-autoinstall.iso"
}

variable "user_data" {
  type    = string
  default = "autoinstall/user-data.yaml"
}

variable "meta_data" {
  type    = string
  default = "autoinstall/meta-data"
}

source "null" "autoinstall_iso" {
  communicator = "none"
}

build {
  sources = ["source.null.autoinstall_iso"]

  provisioner "shell-local" {
    command = "bash ${path.root}/../scripts/build-autoinstall-iso.sh '${var.source_iso}' '${var.output_iso}' '${var.user_data}' '${var.meta_data}'"
  }
}

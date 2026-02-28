packer {}

variable "source_iso" {
  type    = string
  default = "ubuntu.iso"
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
    command = "cd ${path.root}/.. && bash scripts/build-autoinstall-iso.sh '${var.source_iso}' '${var.output_iso}' '${var.user_data}' '${var.meta_data}'"
  }
}

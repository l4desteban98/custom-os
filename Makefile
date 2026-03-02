
DISK ?= /dev/disk4
RDISK := $(DISK:/dev/disk%=/dev/rdisk%)

build:
	@cd packer && PACKER_LOG=1 packer build .

pack:
	@diskutil unmountDisk ${DISK}
	@sudo dd if=/Users/lerix/Projects/sandbox/custom-os/ubuntu-lerix-autoinstall.iso of=${RDISK} bs=4m
	@diskutil eject ${DISK}
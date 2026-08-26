# nixos-cloud-init-installer

A minimal x86_64 NixOS cloud image for Proxmox with cloud-init support.

This image is intended to be used like a Fedora Cloud image: build a reusable UEFI QCOW2 base image, import it into Proxmox, attach a Proxmox cloud-init drive, and provision the VM at first boot through cloud-init.

## Image defaults

- Architecture: `x86_64-linux`
- Firmware: UEFI/OVMF
- Disk format: QCOW2 by default; release builds use compressed QCOW2
- Hypervisor target: Proxmox/QEMU/KVM
- Cloud-init datasource: `NoCloud` and `ConfigDrive`, covering Proxmox Linux cloud-init seed formats
- Network renderer: `systemd-networkd`, with an image-side DHCP fallback on normal Ethernet interfaces when cloud-init does not provide network config
- Guest agent: QEMU guest agent enabled
- Root filesystem: ext4 with grow-on-boot support
- SSH: OpenSSH enabled, TCP port 22 opened in the guest firewall, password authentication enabled, and root SSH login permitted by image default. The image is root-only by default; Proxmox/cloud-init can set root passwords/keys with normal portable cloud-init data.
- NixOS configuration: the image includes this flake under `/etc/nixos` so it can be inspected and rebuilt from inside the VM.

The image intentionally keeps the package set small. It includes `cloud-init`, `curl`, `nano`, and `vim`.

## Build

This assumes Nix is installed with flakes and `nix-command` enabled.

```bash
nix build .#qcow2
```

The default QCOW2 output is not internally compressed, which is faster and better for normal development/provisioning workflow runs.

For a smaller release artifact, build the compressed QCOW2 output:

```bash
nix build .#qcow2-compressed
```

The resulting image will be available under `result/`, with a filename similar to:

```text
nixos-cloud-proxmox-26.05.DATE.HASH-x86_64.qcow2
```

You can also build the native Proxmox VMA backup artifact exposed by nixpkgs' Proxmox image module:

```bash
nix build .#vma
```

## Example Proxmox import flow

The exact storage names and VM IDs depend on your Proxmox environment. This example imports the QCOW2 as a template VM.

```bash
qm create 9000 \
  --name nixos-cloud \
  --memory 1024 \
  --cores 1 \
  --net0 virtio,bridge=vmbr0,firewall=1 \
  --ostype l26 \
  --bios ovmf \
  --machine q35 \
  --agent enabled=1 \
  --serial0 socket \
  --vga serial0

qm importdisk 9000 result/nixos-cloud-proxmox-*.qcow2 local-lvm
qm set 9000 --scsihw virtio-scsi-single --virtio0 local-lvm:vm-9000-disk-0
qm set 9000 --efidisk0 local-lvm:0,efitype=4m,pre-enrolled-keys=0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot order=virtio0
qm template 9000
```

For clones, provide cloud-init data through Proxmox, for example with `qm set` or your provider's provisioning layer.

If Proxmox/OVMF reports `no bootable option found`, verify that the imported OS disk is the disk named in `--boot order=...`. On `local-lvm`, Proxmox allocates disk numbers in creation order; if you create `efidisk0` before running `qm importdisk`, the EFI vars disk may become `vm-9000-disk-0` and the imported OS disk may become `vm-9000-disk-1`. In that case, attach the imported OS disk instead, for example:

```bash
qm set 9000 --virtio0 local-lvm:vm-9000-disk-1
qm set 9000 --boot order=virtio0
```

If your provisioning workflow resizes the VM disk after cloning, the image is prepared for that: the Proxmox image module enables partition growth and root filesystem auto-resize on boot.

## Example cloud-init user data

For root SSH key login, the base image defaults are enough:

```yaml
#cloud-config
disable_root: false
users:
  - name: root
    ssh_authorized_keys:
      - ssh-ed25519 AAAA... user@example
```

For root password SSH login, set the root password. Use hashed passwords in production when possible.

```yaml
#cloud-config
ssh_pwauth: true
disable_root: false
chpasswd:
  expire: false
  users:
    - name: root
      password: "$6$rounds=4096$exampleSalt$replace-with-a-real-sha512-crypt-hash"

```

## Notes

- This repository currently targets Proxmox only. Future support for cloud-hypervisor should likely be added as a separate image module/output rather than mixing defaults.
- The image pins NixOS through `flake.nix`. Update the `nixpkgs` input when moving to a new NixOS release.
- If your Proxmox storage or network bridge differs from `local-lvm`/`vmbr0`, adjust both the image configuration and Proxmox import commands accordingly.

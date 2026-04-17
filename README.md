# nixos-lima

A Nix flake that builds NixOS VM images for [Lima](https://lima-vm.io) and provides a NixOS module for Lima boot-time support. The module configures the VM at first boot using Lima userdata and runs `lima-guestagent` as a systemd service.

## Installation

1. Install Lima (via Homebrew, Nix, or the [Lima docs](https://lima-vm.io/docs/installation/))
2. Start the VM:

```bash
limactl create --name nixos https://raw.githubusercontent.com/saronic-technologies/nixos-lima/main/lima.yaml
limactl start nixos
```

`limactl create` opens an editor to review and customize the config before the VM is created. You can also set resources inline:

```bash
limactl create --name nixos --cpus 4 --memory 8 --disk 128 https://raw.githubusercontent.com/saronic-technologies/nixos-lima/main/lima.yaml
```

3. Open a shell in the VM:


```bash
limactl shell nixos
```

## Modifying the Config

Three files control the VM:

- **`image.nix`** — Base NixOS configuration: packages, boot, filesystems, Nix daemon settings
- **`lima.nix`** — Lima module: user creation, SSH keys, mounts, and `lima-guestagent`
- **`lima.yaml`** — Lima VM settings: CPU, memory, disk size, host mounts, port forwarding

If you already have a running VM, use `nixos-rebuild` to apply changes — no need to rebuild the image. Build a new image when you need a fresh VM from scratch or want to distribute an updated image.

## Rebuilding

### Apply config changes to a running VM

From inside the VM, with the repo directory accessible:

```bash
sudo nixos-rebuild switch --flake /path/to/nixos-lima#nixos-aarch64
```

Or driven from the host:

```bash
limactl shell nixos -- sudo nixos-rebuild switch --flake .#nixos-aarch64
```

Restart the VM after rebuilding to re-run `lima-init` and restore shared mounts:

```bash
limactl restart nixos
```

### Build a new image

Building requires a Linux host or builder. The running VM itself can build images if the repo is mounted from the host.

```bash
# Standard image
nix build .#packages.aarch64-linux.nixos-image

# With Determinate Nix
nix build .#packages.aarch64-linux.nixos-determinate-image

# x86_64 variants
nix build .#packages.x86_64-linux.nixos-image
nix build .#packages.x86_64-linux.nixos-determinate-image
```

The image is output to `./result/nixos.qcow2`. To use it, update the `images:` section of `lima.yaml` to point to the local path, then recreate the VM:

```bash
limactl delete nixos
limactl start --name nixos lima.yaml
```

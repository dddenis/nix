{ pkgs ? import <nixpkgs> { }, blockDevice, systemName }:

pkgs.mkShell {
  buildInputs = [
    pkgs.nixFlakes
    pkgs.parted
  ];
  shellHook = ''
    set -eou pipefail

    # https://nixos.org/manual/nixos/stable/#sec-installation
    echo "Installing NixOS system "${systemName}" on /dev/${blockDevice}"

    parted /dev/${blockDevice} -- mklabel gpt
    parted /dev/${blockDevice} -- mkpart primary 512MiB -8GiB
    parted /dev/${blockDevice} -- mkpart primary linux-swap -8GiB 100%
    parted /dev/${blockDevice} -- mkpart ESP fat32 1MiB 512MiB
    parted /dev/${blockDevice} -- set 3 esp on

    mkfs.ext4 -L nixos /dev/${blockDevice}p1
    mkswap -L swap /dev/${blockDevice}p2
    mkfs.fat -F 32 -n boot /dev/${blockDevice}p3
    mount /dev/disk/by-label/nixos /mnt
    mkdir -p /mnt/boot
    mount /dev/disk/by-label/boot /mnt/boot
    nixos-install --flake "/nix-config#${systemName}" --no-root-passwd -v
    reboot
  '';
}

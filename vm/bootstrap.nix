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
    parted /dev/${blockDevice} -- mkpart nixos 512MiB -8GiB
    parted /dev/${blockDevice} -- mkpart swap linux-swap -8GiB 100%
    parted /dev/${blockDevice} -- mkpart ESP fat32 1MiB 512MiB
    parted /dev/${blockDevice} -- set 3 esp on

    mkfs.ext4 -L nixos /dev/disk/by-partlabel/nixos
    mkswap -L swap /dev/disk/by-partlabel/swap
    mkfs.fat -F 32 -n boot /dev/disk/by-partlabel/ESP
    mount /dev/disk/by-label/nixos /mnt
    mkdir -p /mnt/boot
    mount /dev/disk/by-label/boot /mnt/boot
    nixos-generate-config --root /mnt --dir /../nix-config/hosts/${systemName}
    nixos-install --no-root-passwd --verbose --flake /nix-config#${systemName}
  '';
}

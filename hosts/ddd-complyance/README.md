```bash
gdisk /dev/nvme0n1

cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup luksOpen /dev/nvme0n1p2 nix

pvcreate /dev/mapper/nix
vgcreate vg /dev/mapper/nix
lvcreate -n swap -L 8GB vg
lvcreate -n root -l '+100%FREE' vg

mkfs.vfat -n boot /dev/nvme0n1p1
mkfs.ext4 -L root /dev/vg/root
mkswap -L swap /dev/vg/swap

swapon /dev/vg/swap
mount /dev/vg/root /mnt
mkdir /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot

nix-shell -p git
git clone https://github.com/dddenis/nix.git .nix
cd .nix
nixos-generate-config --show-hardware-config --root /mnt > hosts/ddd-complyance/hardware-configuration.nix
lsblk -o name,type,mountpoint,uuid
vim hosts/ddd-complyance/default.nix
git add .
nixos-install --flake .#ddd-complyance
cd ..
mv .nix /mnt/etc/.nix
```

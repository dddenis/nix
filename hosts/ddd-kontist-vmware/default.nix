{ config, lib, options, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ../../vm/vmware-guest.nix ];

  disabledModules = [ "virtualisation/vmware-guest.nix" ];

  profiles.vm.enable = true;
  profiles.work.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_5_15;

  virtualisation.vmware.guest.enable = true;

  networking.interfaces.ens160.useDHCP = true;

  fileSystems."/host" = {
    fsType = "fuse./run/current-system/sw/bin/vmhgfs-fuse";
    device = ".host:/";
    options = [
      "umask=22"
      "uid=1000"
      "gid=1000"
      "allow_other"
      "auto_unmount"
      "defaults"
    ];
  };

  fileSystems."/proc/sys/fs/binfmt_misc" = {
    fsType = "binfmt_misc";
    device = "binfmt_misc";
  };
}

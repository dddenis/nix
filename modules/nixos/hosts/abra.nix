{ config, lib, pkgs, ... }:

let cfg = config.ddd.hosts.abra;

in
{
  options.ddd.hosts.abra.enable = lib.mkEnableOption "abra";

  config = lib.mkIf cfg.enable {
    nix.buildMachines = [
      {
        hostName = "abra";
        system = "aarch64-linux";
        protocol = "ssh-ng";
        sshUser = "builder";
        sshKey = config.sops.secrets."ssh/keys/builder@ddd-pc".path;
      }
    ];

    sops.secrets."ssh/keys/builder@ddd-pc" = { };
  };
}

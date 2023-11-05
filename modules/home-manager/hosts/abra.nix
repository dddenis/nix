{ config, lib, pkgs, ... }:

let cfg = config.ddd.hosts.abra;

in
{
  options.ddd.hosts.abra.enable = lib.mkEnableOption "abra";

  config = lib.mkIf cfg.enable {
    programs.ssh.includes = [
      config.sops.secrets."ssh/includes/abra".path
    ];

    sops.secrets."ssh/includes/abra".path = "${config.home.homeDirectory}/.ssh/includes/abra";
  };
}

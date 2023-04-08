{ config, lib, pkgs, ... }:

let cfg = config.ddd.programs.ssh;

in
{
  options.ddd.programs.ssh.enable = lib.mkEnableOption "ssh";

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;

      extraConfig = lib.mkIf pkgs.stdenv.isDarwin ''
        UseKeychain = yes
      '';
    };
  };
}

{ config, lib, pkgs, ... }:

let
  cfg = config.programs.fd;

in
{
  options.programs.fd.enable' = lib.mkEnableOption "fd";

  config = lib.mkIf cfg.enable' {
    hm.home.packages = [ pkgs.fd ];

    hm.xdg.configFile."fd/ignore".text = ''
      .git
    '';
  };
}

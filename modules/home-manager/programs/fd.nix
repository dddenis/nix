{ config, lib, pkgs, ... }:

let cfg = config.ddd.programs.fd;

in
{
  options.ddd.programs.fd.enable = lib.mkEnableOption "fd";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.fd ];
  };
}

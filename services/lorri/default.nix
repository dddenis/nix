{ config, lib, pkgs, ... }:

let cfg = config.services.lorri;

in {
  options.services.lorri.enable' = lib.mkEnableOption "lorri";

  config = lib.mkIf cfg.enable' {
    home.packages = [ pkgs.lorri ];

    programs.direnv.enable' = true;
  };
}

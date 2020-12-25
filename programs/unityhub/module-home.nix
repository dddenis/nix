{ config, lib, pkgs, ... }:

let cfg = config.programs.unityhub;

in {
  options.programs.unityhub.enable' = lib.mkEnableOption "unityhub";

  config = lib.mkIf cfg.enable' { home.packages = [ pkgs.unityhub ]; };
}

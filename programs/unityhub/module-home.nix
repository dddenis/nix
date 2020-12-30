{ config, lib, pkgs, ... }:

let
  cfg = config.programs.unityhub;

  desktopItem = pkgs.makeDesktopItem {
    name = "UnityHub";
    desktopName = "UnityHub";
    exec = "${pkgs.unityhub}/bin/unityhub";
  };

in {
  options.programs.unityhub.enable' = lib.mkEnableOption "unityhub";

  config =
    lib.mkIf cfg.enable' { home.packages = [ desktopItem pkgs.unityhub ]; };
}

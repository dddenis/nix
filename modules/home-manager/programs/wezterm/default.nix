{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.wezterm;

in
{
  options.ddd.programs.wezterm = {
    enable = lib.mkEnableOption "wezterm";
    package = lib.mkPackageOption pkgs.unstable "wezterm" { };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
    xdg.configFile."wezterm".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.configPath}/modules/home-manager/programs/wezterm/config";
  };
}

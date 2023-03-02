{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.lf;

in
{
  options.ddd.programs.lf.enable = lib.mkEnableOption "lf";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.unstable.lf ];

    xdg.configFile."lf/lfrc".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.configPath}/modules/home-manager/programs/lf/lfrc";
  };
}

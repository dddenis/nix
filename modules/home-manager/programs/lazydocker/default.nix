{ config, lib, pkgs, ... }:

let cfg = config.ddd.programs.lazydocker;

in
{
  options.ddd.programs.lazydocker.enable = lib.mkEnableOption "lazydocker";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.lazydocker ];
    xdg.configFile."lazydocker/config.yml".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.configPath}/modules/home-manager/programs/lazydocker/config.yml";
  };
}

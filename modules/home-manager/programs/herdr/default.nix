{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.herdr;
  herdrConfigPath = "${config.home.configPath}/modules/home-manager/programs/herdr";

in
{
  options.ddd.programs.herdr.enable = lib.mkEnableOption "herdr";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.unstable.herdr ];

    xdg.configFile = {
      "herdr/config.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${herdrConfigPath}/config.toml";
      "herdr/notification.mp3".source =
        config.lib.file.mkOutOfStoreSymlink
          "${herdrConfigPath}/notification.mp3";
    };
  };
}

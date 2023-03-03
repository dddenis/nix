{ config, lib, pkgs, ... }:

let cfg = config.ddd.services.safeeyes;

in
{
  options.ddd.services.safeeyes.enable = lib.mkEnableOption "safeeyes";

  config = lib.mkIf cfg.enable {
    services.safeeyes.enable = true;
    services.safeeyes.package = pkgs.unstable.safeeyes;

    systemd.user.services.safeeyes.Service.Environment = [
      # Fix overlay covering only one monitor on Wayland
      "GDK_BACKEND=x11"
    ];

    xdg.configFile."safeeyes/safeeyes.json".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.configPath}/modules/home-manager/services/safeeyes/safeeyes.json";
    xdg.configFile."safeeyes/style/safeeyes_style.css".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.configPath}/modules/home-manager/services/safeeyes/safeeyes_style.css";
  };
}

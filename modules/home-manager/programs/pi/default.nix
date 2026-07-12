{ config, lib, ... }:

let
  cfg = config.ddd.programs.pi;
  piConfigPath = "${config.home.configPath}/modules/home-manager/programs/pi";

in
{
  options.ddd.programs.pi.enable = lib.mkEnableOption "pi";

  config = lib.mkIf cfg.enable {
    home.file.".pi/agent/settings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink
        "${piConfigPath}/settings.json";
      force = true;
    };

    home.file.".pi/agent/themes" = {
      source = config.lib.file.mkOutOfStoreSymlink
        "${piConfigPath}/themes";
      force = true;
    };
  };
}

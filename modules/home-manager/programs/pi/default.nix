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

    home.file.".pi/agent/extensions/custom-footer" = {
      source = config.lib.file.mkOutOfStoreSymlink
        "${piConfigPath}/extensions/custom-footer";
      force = true;
    };

    home.file.".pi/agent/extensions/attention-hooks" = {
      source = config.lib.file.mkOutOfStoreSymlink
        "${piConfigPath}/extensions/attention-hooks";
      force = true;
    };

    home.file.".pi/agent/extensions/history-picker" = {
      source = config.lib.file.mkOutOfStoreSymlink
        "${piConfigPath}/extensions/history-picker";
      force = true;
    };
  };
}

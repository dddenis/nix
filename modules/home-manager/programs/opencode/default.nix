{ config, lib, ... }:

let
  cfg = config.ddd.programs.opencode;
  opencodeConfigPath = "${config.home.configPath}/modules/home-manager/programs/opencode";

in
{
  options.ddd.programs.opencode.enable = lib.mkEnableOption "opencode";

  config = lib.mkIf cfg.enable {
    xdg.configFile = {
      "opencode/agent".source =
        config.lib.file.mkOutOfStoreSymlink "${opencodeConfigPath}/agent";
      "opencode/command".source =
        config.lib.file.mkOutOfStoreSymlink "${opencodeConfigPath}/command";
      "opencode/opencode.jsonc".source =
        config.lib.file.mkOutOfStoreSymlink "${opencodeConfigPath}/opencode.jsonc";
      "opencode/plugins".source =
        config.lib.file.mkOutOfStoreSymlink "${opencodeConfigPath}/plugins";
    };
  };
}

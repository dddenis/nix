{ config, lib, ... }:

let
  cfg = config.ddd.agents;
  agentsConfigPath = "${config.home.configPath}/modules/home-manager/agents";

in
{
  options.ddd.agents.enable = lib.mkEnableOption "agents";

  config = lib.mkIf cfg.enable {
    home.file.".agents/skills" = {
      source = config.lib.file.mkOutOfStoreSymlink
        "${agentsConfigPath}/skills";
      force = true;
    };
  };
}

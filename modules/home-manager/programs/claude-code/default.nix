{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.claude-code;

in
{
  options.ddd.programs.claude-code.enable = lib.mkEnableOption "claude-code";

  config = lib.mkIf cfg.enable {
    # home.packages = [ pkgs.unstable.claude-code ];

    home.file.".claude/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.configPath}/modules/home-manager/programs/claude-code/settings.json";
  };
}

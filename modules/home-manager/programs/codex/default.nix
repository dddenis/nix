{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.codex;

in
{
  options.ddd.programs.codex.enable = lib.mkEnableOption "codex";

  config = lib.mkIf cfg.enable {
    # home.packages = [ pkgs.unstable.codex ];

    home.file.".codex/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.configPath}/modules/home-manager/programs/codex/config.toml";

    home.file.".codex/hooks.json".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.configPath}/modules/home-manager/programs/codex/hooks.json";
  };
}

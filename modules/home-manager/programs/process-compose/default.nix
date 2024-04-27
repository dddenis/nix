{ config, lib, pkgs, ... }:

let cfg = config.ddd.programs.process-compose;

in
{
  options.ddd.programs.process-compose.enable = lib.mkEnableOption "process-compose";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.unstable.process-compose ];

    xdg.configFile."process-compose/shortcuts.yaml".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.configPath}/modules/home-manager/programs/process-compose/shortcuts.yaml";
  };
}

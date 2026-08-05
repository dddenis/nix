{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ddd.programs.herdr;
  herdrConfigPath = "${config.home.configPath}/modules/home-manager/programs/herdr";
  workspaceLastTabPluginPath = "${herdrConfigPath}/plugins/workspace-last-tab";
  workspaceLastWorkspacePluginPath = "${herdrConfigPath}/plugins/workspace-last-workspace";

in
{
  options.ddd.programs.herdr.enable = lib.mkEnableOption "herdr";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.unstable.herdr ];

    home.activation.linkHerdrWorkspaceLastTab = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.unstable.herdr}/bin/herdr plugin link \
        ${lib.escapeShellArg workspaceLastTabPluginPath}
    '';

    home.activation.linkHerdrWorkspaceLastWorkspace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.unstable.herdr}/bin/herdr plugin link \
        ${lib.escapeShellArg workspaceLastWorkspacePluginPath}
    '';

    xdg.configFile = {
      "herdr/config.toml".source = config.lib.file.mkOutOfStoreSymlink "${herdrConfigPath}/config.toml";
      "herdr/notification.mp3".source =
        config.lib.file.mkOutOfStoreSymlink "${herdrConfigPath}/notification.mp3";
    };
  };
}

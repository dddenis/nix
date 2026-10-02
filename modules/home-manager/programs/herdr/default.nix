{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ddd.programs.herdr;
  herdrConfigPath = "${config.home.configPath}/modules/home-manager/programs/herdr";
  soundTogglePluginPath = "${herdrConfigPath}/plugins/sound-toggle";
  workspaceLastTabPluginPath = "${herdrConfigPath}/plugins/workspace-last-tab";
  workspaceLastWorkspacePluginPath = "${herdrConfigPath}/plugins/workspace-last-workspace";
  lsof = if pkgs.stdenv.isDarwin then "/usr/sbin/lsof" else "${pkgs.lsof}/bin/lsof";
  restartAgents = pkgs.writeShellScriptBin "herd-restart-agents" ''
    exec ${pkgs.python3}/bin/python3 -I -B -c \
      'import sys; sys.path.insert(0, sys.argv.pop(1)); from cli import main; sys.exit(main(herdr=sys.argv.pop(1), profile_bin=sys.argv.pop(1), lsof=sys.argv.pop(1)))' \
      ${./restart} ${pkgs.unstable.herdr}/bin/herdr \
      ${lib.escapeShellArg "${config.home.profileDirectory}/bin"} \
      ${lib.escapeShellArg lsof} "$@"
  '';

in
{
  options.ddd.programs.herdr.enable = lib.mkEnableOption "herdr";

  config = lib.mkIf cfg.enable {
    # Manual after switching generations; --dry-run previews without stopping agents.
    home.packages = [ pkgs.unstable.herdr restartAgents ];

    home.activation.linkHerdrSoundToggle = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.unstable.herdr}/bin/herdr plugin link \
        ${lib.escapeShellArg soundTogglePluginPath}
    '';

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

{ userConfig }:
{ config, lib, pkgs, ... }:

{
  config = lib.mkIf userConfig.services.lorri.enable' {
    launchd.user.agents.lorri-daemon = {
      serviceConfig = {
        WorkingDirectory = (builtins.getEnv "HOME");
        EnvironmentVariables = { };
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/tmp/lorri.log";
        StandardErrorPath = "/var/tmp/lorri.log";
      };

      script = ''
        source ${config.system.build.setEnvironment}
        exec ${pkgs.lorri}/bin/lorri daemon
      '';
    };
  };
}

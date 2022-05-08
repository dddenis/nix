{ config, lib, options, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  profiles.vm.enable = true;
  profiles.work.enable = true;

  environment.variables.LIBGL_ALWAYS_SOFTWARE = "1";

  programs.gnupg.agent.enable = true;

  systemd.user.services.spice-vdagent = {
    description = "Spice vdagent client";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.spice-vdagent}/bin/spice-vdagent --debug --foreground";
      Restart = "always";
      RestartSec = 2;
    };
  };

  services.spice-vdagentd.enable = true;
}

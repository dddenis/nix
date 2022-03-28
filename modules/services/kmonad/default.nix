{ config, lib, pkgs, ... }:

let cfg = config.services.kmonad;

in {
  options.services.kmonad.enable' = lib.mkEnableOption "kmonad";

  config = lib.mkIf cfg.enable' {
    users.groups.uinput = { };

    user.extraGroups = [ "input" "uinput" ];

    services.udev.extraRules = ''
      # KMonad user access to /dev/uinput
      KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
    '';

    hm.systemd.user.services.kmonad = {
      Unit = {
        Description = "kmonad";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${pkgs.kmonad}/bin/kmonad ${./config.kbd}";
        Restart = "on-abort";
      };

      Install = { WantedBy = [ "graphical-session.target" ]; };
    };
  };
}

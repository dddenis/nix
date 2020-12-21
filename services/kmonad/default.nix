{ config, lib, pkgs, ... }:

let cfg = config.services.kmonad;

in {
  options.services.kmonad = {
    enable = lib.mkEnableOption "kmonad";

    config = lib.mkOption {
      type = lib.types.path;
      default = ./config.kbd;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.kmonad = {
      Unit = {
        Description = "kmonad";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${pkgs.kmonad}/bin/kmonad ${cfg.config}";
        Restart = "on-abort";
      };

      Install = { WantedBy = [ "graphical-session.target" ]; };
    };
  };
}

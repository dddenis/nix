{ config, lib, ... }:

let cfg = config.services.xcape;

in {
  options.services.xcape.enable' = lib.mkEnableOption "xcape";

  config = lib.mkIf cfg.enable' {
    services.xcape.enable = true;

    systemd.user.services.xcape.Unit.After =
      lib.mkForce [ "graphical-session.target" ];
  };
}

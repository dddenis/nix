{ config, lib, pkgs, ... }:

let cfg = config.ddd.services.kmonad;

in
{
  options.ddd.services.kmonad.enable = lib.mkEnableOption "kmonad";

  config = lib.mkIf cfg.enable {
    services.kmonad.enable = true;

    services.kmonad.keyboards.hhkb = {
      device = "/dev/input/by-id/usb-PFU_Limited_HHKB-Classic-event-kbd";
      config = builtins.readFile ./config.kbd;
    };
  };
}

{ config, lib, ... }:

let cfg = config.home;

in lib.mkIf cfg.enable' {
  xdg = {
    mimeApps.enable = true;
    configFile."mimeapps.list".force = true;
  };
}

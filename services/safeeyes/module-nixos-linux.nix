{ config, lib, options, ... }:

let cfg = config.services.safeeyes;

in {
  options.services.safeeyes = { enable' = lib.mkEnableOption "safeeyes"; };

  config = lib.mkIf cfg.enable' { services.safeeyes.enable = true; };
}

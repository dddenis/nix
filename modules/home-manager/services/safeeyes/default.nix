{ config, lib, options, ... }:

let cfg = config.ddd.services.safeeyes;

in
{
  options.ddd.services.safeeyes.enable = lib.mkEnableOption "safeeyes";

  config = lib.mkIf cfg.enable {
    services.safeeyes.enable = true;
    xdg.configFile."safeeyes/safeeyes.json".source = ./safeeyes.json;
  };
}

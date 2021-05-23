{ config, lib, nixosConfig, options, ... }:

let cfg = nixosConfig.services.safeeyes;

in {
  config = lib.mkIf cfg.enable' {
    xdg.configFile."safeeyes/safeeyes.json".source = ./safeeyes.json;
  };
}

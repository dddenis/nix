{ config, lib, ... }:

let cfg = config.services.lorri;

in {
  options.services.lorri.enable' = lib.mkEnableOption "lorri";

  config = lib.mkIf cfg.enable' { programs.direnv.enable' = true; };
}

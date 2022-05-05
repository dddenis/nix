{ config, lib, pkgs, ... }:

let cfg = config.programs.psql;

in {
  options.programs.psql.enable' = lib.mkEnableOption "psql";

  config = lib.mkIf cfg.enable' {
    hm.home = {
      packages = [ pkgs.postgresql ];
      sessionVariables = { PSQL_PAGER = "${pkgs.pspg}/bin/pspg -s 0"; };
    };
  };
}

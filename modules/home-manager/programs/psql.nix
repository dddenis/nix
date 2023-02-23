{ config, lib, pkgs, ... }:

let cfg = config.ddd.programs.psql;

in
{
  options.ddd.programs.psql.enable = lib.mkEnableOption "psql";

  config = lib.mkIf cfg.enable {
    home = {
      packages = [ pkgs.postgresql ];
      sessionVariables = { PSQL_PAGER = "${pkgs.pspg}/bin/pspg -s 0"; };
    };
  };
}

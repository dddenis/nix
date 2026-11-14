{ config, lib, ... }:

let cfg = config.ddd.programs.ripgrep;

in
{
  options.ddd.programs.ripgrep.enable = lib.mkEnableOption "ripgrep";

  config = lib.mkIf cfg.enable {
    programs.ripgrep = {
      enable = true;
      arguments = [ "--type-add" "gql:*.graphql" ];
    };
  };
}

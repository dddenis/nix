{ config, lib, pkgs, ... }:

let
  cfg = config.programs.ripgrep;
  configPath = "ripgrep/.ripgreprc";

in {
  options.programs.ripgrep.enable' = lib.mkEnableOption "ripgrep";

  config = lib.mkIf cfg.enable' {
    hm.home = {
      packages = [ pkgs.ripgrep ];

      sessionVariables = {
        RIPGREP_CONFIG_PATH = "${config.hm.xdg.configHome}/${configPath}";
      };
    };

    hm.xdg.configFile."${configPath}".text = ''
      --type-add
      gql:*.graphql
    '';
  };
}

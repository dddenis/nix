{ config, lib, pkgs, ... }:

let
  cfg = config.programs.ripgrep;
  configPath = "ripgrep/.ripgreprc";

in {
  options.programs.ripgrep.enable' = lib.mkEnableOption "ripgrep";

  config = lib.mkIf cfg.enable' {
    home = {
      packages = [ pkgs.ripgrep ];

      sessionVariables = {
        RIPGREP_CONFIG_PATH = "${config.xdg.configHome}/${configPath}";
      };
    };

    xdg.configFile."${configPath}".text = ''
      --type-add
      gql:*.graphql
    '';
  };
}

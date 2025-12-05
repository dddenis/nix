{ config, lib, ... }:

let cfg = config.ddd.programs.delta;

in
{
  options.ddd.programs.delta.enable = lib.mkEnableOption "delta";

  config = lib.mkIf cfg.enable {
    programs.delta = lib.mkDefault {
      enable = true;
      enableGitIntegration = true;

      options = {
        features = "decorations line-numbers";
        syntax-theme = "gruvbox-dark";

        decorations = {
          file-style = "blue box";
          hunk-header-style = "omit";
        };
      };
    };
  };
}

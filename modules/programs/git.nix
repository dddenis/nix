{ config, lib, ... }:

let cfg = config.programs.git;

in {
  options.programs.git.enable' = lib.mkEnableOption "git";

  config = lib.mkIf cfg.enable' {
    hm.programs.git = lib.mkDefault {
      enable = true;
      userName = "Denis Goncharenko";
      userEmail = "dddenjer@gmail.com";
      ignores = [ ".DS_Store" ".direnv/" ".envrc" ".ignore" ];

      delta = {
        enable = true;

        options = {
          features = "decorations line-numbers";
          syntax-theme = "gruvbox-dark";

          decorations = {
            file-style = "blue box";
            hunk-header-style = "omit";
          };
        };
      };

      extraConfig = {
        fetch.prune = true;
        pull.rebase = true;
      };
    };
  };
}

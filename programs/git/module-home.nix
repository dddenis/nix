{ config, lib, ... }:

let cfg = config.programs.git;

in {
  options.programs.git.enable' = lib.mkEnableOption "git";

  config = lib.mkIf cfg.enable' (lib.mkDefault {
    programs.git = {
      enable = true;
      userName = "Denis Goncharenko";
      userEmail = "dddenjer@gmail.com";
      ignores = [ ".DS_Store" ".direnv/" ".ignore" ".log/" ".vim/" ];

      delta = {
        enable = true;

        options = {
          features = "side-by-side line-numbers decorations";
          syntax-theme = "gruvbox-dark";

          decorations = {
            commit-decoration-style = "bold yellow box ul";
            file-style = "bold yellow ul";
            file-decoration-style = "none";
            whitespace-error-style = "22 reverse";
          };
        };
      };

      extraConfig = { pull.rebase = true; };
    };
  });
}

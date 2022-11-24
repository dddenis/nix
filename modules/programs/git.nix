{ config, lib, ... }:

let cfg = config.programs.git;

in
{
  options.programs.git.enable' = lib.mkEnableOption "git";

  config = lib.mkIf cfg.enable' {
    hm.programs.git = lib.mkDefault {
      enable = true;
      userName = "Denis Goncharenko";
      userEmail = "dddenjer@gmail.com";
      ignores = [
        ".direnv/"
        ".git/"
        ".DS_Store"
        ".envrc"
        ".ignore"
      ];

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

      aliases = {
        skip = "!git diff --name-only | xargs git update-index --skip-worktree";
        unskip = "!git ls-files -v | grep -i ^S | cut -c 3- | xargs git update-index --no-skip-worktree";
      };

      extraConfig = {
        fetch.prune = true;
        pull.rebase = true;

        merge = {
          tool = "vim_mergetool";
          conflictStyle = "diff3";
        };

        mergetool = {
          keepBackup = false;

          vim_mergetool = {
            cmd = ''nvim -f -c "MergetoolStart" "$MERGED" "$BASE" "$LOCAL" "$REMOTE"'';
            trustExitCode = true;
          };
        };
      };
    };
  };
}

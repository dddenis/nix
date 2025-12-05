{ config, lib, ... }:

let cfg = config.ddd.programs.git;

in
{
  options.ddd.programs.git.enable = lib.mkEnableOption "git";

  config = lib.mkIf cfg.enable {
    programs.git = lib.mkDefault {
      enable = true;

      ignores = [
        ".direnv/"
        ".git/"
        ".DS_Store"
        ".envrc"
        ".rgignore"
      ];

      settings = {
        user = {
          name = "Denis Goncharenko";
          email = "dddenjer@gmail.com";
        };

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

        rebase = {
          updateRefs = true;
        };

        alias = {
          skip = "!git diff --name-only | xargs git update-index --skip-worktree";
          unskip = "!git ls-files -v | grep -i ^S | cut -c 3- | xargs git update-index --no-skip-worktree";
        };
      };
    };
  };
}

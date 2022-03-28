{ config, lib, pkgs, ... }:

let
  cfg = config.programs.lazygit;

  delta = "${pkgs.delta}/bin/delta";
  lazygit = "${pkgs.lazygit}/bin/lazygit";

  logCmd =
    "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'";

in {
  options.programs.lazygit.enable' = lib.mkEnableOption "lazygit";

  config = lib.mkIf cfg.enable' {
    hm.programs = {
      lazygit = {
        enable = true;

        settings = {
          git = {
            branchLogCmd = "${logCmd} {{branchName}} --";
            allBranchesLogCmd = "${logCmd} --all";
            skipHookPrefix = "--wip-- [skip ci]";

            paging = {
              colorArg = "always";
              pager = "${delta} --paging=never";
            };
          };

          gui = {
            mouseEvents = false;
            showCommandLog = false;
          };
        };
      };

      zsh.shellAliases = { gg = lazygit; };
    };
  };
}

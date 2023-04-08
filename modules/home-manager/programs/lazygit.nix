{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.lazygit;

  delta = "${pkgs.delta}/bin/delta";
  lazygit = "TERM=screen-256color ${pkgs.lazygit}/bin/lazygit";

  logCmd =
    "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'";

in
{
  options.ddd.programs.lazygit.enable = lib.mkEnableOption "lazygit";

  config = lib.mkIf cfg.enable {
    programs = {
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

    xdg.configFile."lazygit/config.yml" = lib.mkIf pkgs.stdenv.isDarwin {
      inherit (config.home.file."Library/Application Support/lazygit/config.yml") source;
    };
  };
}

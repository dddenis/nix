{ pkgs, ... }:

{
  imports = [ ../fonts ../programs ../services ../theme ];

  home.packages = with pkgs; [ cachix niv nnn ];

  fonts.enable' = true;

  programs = {
    bat.enable' = true;
    emacs.enable' = true;
    fzf.enable' = true;
    home-manager.enable = true;
    ripgrep.enable' = true;
    tmux.enable' = true;
    vim.enable' = true;
    vscode.enable' = true;

    alacritty = {
      enable' = true;

      # settings.type == types.attrs;
      # have to redeclare all nested sets
      settings = {
        window.startup_mode = "Maximized";

        font = {
          size = 16;

          normal = {
            family = "Iosevka DDD";
            style = "Extended";
          };
          bold.style = "Bold Extended";
          italic.style = "Extended Oblique";
          bold_italic.style = "Bold Extended Oblique";
        };
      };
    };

    git = {
      enable' = true;
      userEmail = "denis.goncharenko@mcmakler.de";
      ignores = [ "*.org" ".dir-locals.el" ".envrc" "shell.nix" ];
    };

    zsh = {
      enable' = true;
      shellAliases = { "ls" = "ls --color"; };
    };
  };

  services = {
    karabiner.enable' = true;
    lorri.enable' = true;
  };

  xdg.enable = true;
}

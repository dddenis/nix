{ config, pkgs, ... }:

{
  services.skhd = {
    enable = true;

    skhdConfig = ''
      alt + shift - return : open -na ${pkgs.alacritty}/Applications/Alacritty.app --args -e zsh -c ${config.home-manager.users.ddd.programs.tmux.launch}

      alt + shift - e : open -na ${pkgs.emacs}/Applications/Emacs.app
    '';
  };
}

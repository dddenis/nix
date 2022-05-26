{ config, lib, pkgs, ... }:

let cfg = config.programs.zsh;

in {
  options.programs.zsh.enable' = lib.mkEnableOption "zsh";

  config = lib.mkIf cfg.enable' {
    environment.pathsToLink = [ "/share/zsh" ];

    hm.programs.zsh = {
      enable = true;
      enableAutosuggestions = true;
      enableCompletion = true;
      dotDir = ".config/zsh";

      initExtra = ''
        ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=(''${ZSH_AUTOSUGGEST_ACCEPT_WIDGETS:#*forward-char})
        ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS+=(forward-char vi-forward-char)
      '';

      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "vi-mode" ];
      };

      dirHashes = config.home.bookmarks;

      plugins = with pkgs; [
        {
          name = "powerlevel10k";
          file = "powerlevel10k.zsh-theme";
          src = "${zsh-powerlevel10k}/share/zsh-powerlevel10k";
        }
        {
          name = "powerlevel10k-config";
          file = ".p10k.zsh";
          src = ./p10k;
        }
      ];
    };

    hm.programs.dircolors.enableZshIntegration = true;
  };
}

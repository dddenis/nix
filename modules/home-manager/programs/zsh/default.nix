{ config, lib, pkgs, ... }:

let cfg = config.ddd.programs.zsh;

in
{
  options.ddd.programs.zsh.enable = lib.mkEnableOption "zsh";

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      enableCompletion = true;
      dotDir = ".config/zsh";

      initContent = ''
        ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=(''${ZSH_AUTOSUGGEST_ACCEPT_WIDGETS:#*forward-char})
        ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS+=(forward-char vi-forward-char)
      '' + (lib.optionalString pkgs.stdenv.isDarwin ''
        # Nix
        if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
          . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
        fi
        # End Nix
      '');

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
  };
}

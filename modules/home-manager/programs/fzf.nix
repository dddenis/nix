{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.fzf;
  fd = "${pkgs.fd}/bin/fd";
  tree = "${pkgs.tree}/bin/tree";

in
{
  options.ddd.programs.fzf.enable = lib.mkEnableOption "fzf";

  config = lib.mkIf cfg.enable {
    programs.fzf = {
      enable = true;

      changeDirWidgetCommand = "${fd} --type d";
      changeDirWidgetOptions = [ "--preview '${tree} -C {} | head -200'" ];
      defaultCommand = "${fd} --type f --hidden --exclude .git";
      defaultOptions = [ "--height 40%" "--border" ];
      fileWidgetCommand = "${fd} --type f --hidden --exclude .git";
    };

    programs.zsh.initExtra = ''
      _fzf_compgen_path() {
        ${fd} --hidden --follow --exclude .git . "$1"
      }

      _fzf_compgen_dir() {
        ${fd} --type d --hidden --follow --exclude .git . "$1"
      }

      fzf-history-widget () {
          local selected num
          setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2> /dev/null
          selected=($(fc -rl 1 | awk '{ cmd=$0; sub(/^[ \t]*[0-9]+\**[ \t]+/, "", cmd); if (!seen[cmd]++) print $0 }' |
          FZF_DEFAULT_OPTS="--height ''${FZF_TMUX_HEIGHT:-40%} ''${FZF_DEFAULT_OPTS-} -n2..,.. --scheme=history --bind=ctrl-r:toggle-sort,ctrl-z:ignore ''${FZF_CTRL_R_OPTS-} +m" $(__fzfcmd))) 
          local ret=$? 
          if [ -n "$selected" ]
          then
              num=$selected[1] 
              if [ -n "$num" ]
              then
                  LBUFFER="$LBUFFER$(fc -ln "$num" "$num")"
              fi
          fi
          zle reset-prompt
          return $ret
      }
    '';
  };
}

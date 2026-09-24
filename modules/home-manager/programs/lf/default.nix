{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.lf;

in
{
  options.ddd.programs.lf.enable = lib.mkEnableOption "lf";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs.unstable; [ lf visidata ];

    xdg.configFile."lf/lfrc".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.configPath}/modules/home-manager/programs/lf/lfrc";

    programs.zsh.initContent = ''
      lf() {
        local dir_file dir ret=0
        dir_file="$(mktemp "''${TMPDIR:-/tmp}/lf-cd.XXXXXX")" || return
        {
          LF_CD_FILE="$dir_file" command lf "$@" || ret=$?
          if IFS= read -r -d "" dir < "$dir_file"; then
            builtin cd -- "$dir" || ret=$?
          fi
        } always {
          command rm -f -- "$dir_file"
        }
        return "$ret"
      }
    '';
  };
}

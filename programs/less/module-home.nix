{ config, lib, ... }:

let cfg = config.programs.less;

in {
  options.programs.less.enable' = lib.mkEnableOption "less";

  config = lib.mkIf cfg.enable' {
    home.sessionVariables.LESS = lib.concatStringsSep " " [
      "--HILITE-UNREAD"
      "--LONG-PROMPT"
      "--RAW-CONTROL-CHARS"
      "--ignore-case"
      "--jump-target=.5"
      "--quit-if-one-screen"
      "--status-column"
      "--tabs=4"
      "--window=-4"
    ];

    programs.lesspipe.enable = true;
  };
}

{ config, lib, pkgs, ... }:

let
  inherit (lib) types;

  cfg = config.programs.tmux;
  tmux = "${pkgs.tmux}/bin/tmux";

in {
  options.programs.tmux = {
    enable' = lib.mkEnableOption "tmux";

    launch = lib.mkOption {
      type = types.package;
      default = pkgs.writeShellScript "tmux-launch" tmux;
    };
  };

  config = lib.mkIf cfg.enable' {
    programs.tmux = {
      enable = true;

      aggressiveResize = true;
      baseIndex = 1;
      customPaneNavigationAndResize = true;
      escapeTime = 10;
      keyMode = "vi";
      shortcut = "a";
      terminal = "tmux-256color";

      launch = pkgs.writeShellScript "tmux-attach" ''
        (${tmux} ls | grep -vq attached && ${tmux} a) || ${tmux}
      '';

      extraConfig = lib.mkBefore ''
        bind s split-window -v -c '#{pane_current_path}'
        bind v split-window -h -c '#{pane_current_path}'

        bind -T copy-mode-vi v send-keys -X begin-selection
        bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"

        bind-key -n C-h select-pane -L
        bind-key -n C-j select-pane -D
        bind-key -n C-k select-pane -U
        bind-key -n C-l select-pane -R
      '';
    };
  };
}

{ config, lib, pkgs, ... }:

let
  cfg = config.programs.tmux;

  tmux = "${pkgs.tmux}/bin/tmux";

in {
  options.programs.tmux = {
    enable' = lib.mkEnableOption "tmux";

    launch = lib.mkOption {
      type = lib.types.package;
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
      tmuxinator.enable = true;

      plugins = with pkgs.tmuxPlugins; [ gruvbox ];

      launch = pkgs.writeShellScript "tmux-attach" ''
        (${tmux} ls | grep -vq attached && ${tmux} a) || ${tmux}
      '';

      extraConfig = lib.mkBefore ''
        bind q choose-tree -Zs
        bind ` switch-client -l

        bind s split-window -v -c '#{pane_current_path}'
        bind v split-window -h -c '#{pane_current_path}'

        bind -T copy-mode-vi v send-keys -X begin-selection
        bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"

        version_pat='s/^tmux[^0-9]*([.0-9]+).*/\1/p'

        is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
            | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"

        is_fzf="ps -o state= -o comm= -t '#{pane_tty}' \
            | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?fzf$'"

        bind-key -n C-h if-shell "$is_vim" "send-keys C-h" "select-pane -L"
        bind-key -n C-j if-shell "($is_vim || $is_fzf)" "send-keys C-j" "select-pane -D"
        bind-key -n C-k if-shell "($is_vim || $is_fzf)" "send-keys C-k" "select-pane -U"
        bind-key -n C-l if-shell "$is_vim" "send-keys C-l" "select-pane -R"

        tmux_version="$(tmux -V | sed -En "$version_pat")"
        setenv -g tmux_version "$tmux_version"

        if-shell -b '[ "$(echo "$tmux_version < 3.0" | bc)" = 1 ]' \
            "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\'  'select-pane -l'"
        if-shell -b '[ "$(echo "$tmux_version >= 3.0" | bc)" = 1 ]' \
            "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\\\'  'select-pane -l'"

        bind-key -T copy-mode-vi C-h select-pane -L
        bind-key -T copy-mode-vi C-j select-pane -D
        bind-key -T copy-mode-vi C-k select-pane -U
        bind-key -T copy-mode-vi C-l select-pane -R
        bind-key -T copy-mode-vi C-\\ select-pane -l
      '';
    };

    programs.zsh.shellAliases = { mux = "${pkgs.tmuxinator}/bin/tmuxinator"; };

    xdg.configFile."tmuxinator/project.yml".source = ./project.yml;
  };
}

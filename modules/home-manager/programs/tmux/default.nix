{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.tmux;

  tmux = "${pkgs.tmux}/bin/tmux";
  tmuxinator = "${pkgs.tmuxinator}/bin/tmuxinator";

in
{
  options.ddd.programs.tmux.enable = lib.mkEnableOption "tmux";

  config = lib.mkIf cfg.enable {
    programs.tmux = {
      enable = true;

      aggressiveResize = true;
      baseIndex = 1;
      customPaneNavigationAndResize = true;
      escapeTime = 10;
      keyMode = "vi";
      shortcut = "a";
      terminal = "tmux-256color";
      mouse = true;
      tmuxinator.enable = true;

      plugins = with pkgs.tmuxPlugins; [ gruvbox ];

      extraConfig = lib.mkBefore ''
        bind q choose-tree -Zs
        bind ` switch-client -l

        bind s split-window -v -c '#{pane_current_path}'
        bind v split-window -h -c '#{pane_current_path}'

        bind -T copy-mode-vi v send-keys -X begin-selection
        bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"

        # Toggle mouse on/off
        bind-key m \
          set-option -gF mouse "#{?mouse,off,on}" \;\
          display-message "#{?mouse,Mouse: ON,Mouse: OFF}"

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

    programs.zsh.shellAliases = {
      mux = tmuxinator;
      muxinate =
        "${tmuxinator} start project -n $(echo $(basename $PWD) | tr .: _)";
    };

    xdg.configFile."tmuxinator/project.yml".source = ./project.yml;

    ddd.misc.terminfo.names = [
      "tmux"
      "tmux-256color"
      "tmux-direct"
    ];

    ddd.services.xserver.desktopManager.gnome.keybindings.custom = [
      {
        name = "Start tmux";
        binding = "<Super>Return";
        command = "${lib.getExe config.ddd.programs.wezterm.package} start ${tmux}";
      }
    ];
  };
}

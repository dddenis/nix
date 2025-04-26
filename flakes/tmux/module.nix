{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.tmux;

in
{
  options.ddd.programs.tmux = {
    enable = lib.mkEnableOption "tmux";
    tmuxinator.enable = lib.mkEnableOption "tmuxinator";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable (
      let
        paneResizeAmount = "5";
        plugins = with pkgs.tmuxPlugins; [ gruvbox ];

        importPlugin = p: ''
          # ${if lib.types.package.check p then p.pname else p.plugin.pname}
          ${p.extraConfig or ""}
          run-shell ${if lib.types.package.check p then p.rtp else p.plugin.rtp}
        '';

      in
      {
        home.packages = [ pkgs.tmux ];

        # https://gpanders.com/blog/the-definitive-guide-to-using-tmux-256color-on-macos/
        ddd.misc.terminfo.names = [
          "tmux"
          "tmux-256color"
          "tmux-direct"
        ];

        xdg.configFile."tmux/tmux.conf".text = ''
          # tmux-sensible
          run-shell ${pkgs.tmuxPlugins.sensible.rtp}

          set -g default-terminal "tmux-256color"
          set -g default-command ""
          setw -g aggressive-resize on

          set -g base-index 1
          setw -g pane-base-index 1

          set -g status-keys vi
          set -g mode-keys vi

          bind -N "Select pane to the left of the active pane" h select-pane -L
          bind -N "Select pane below the active pane" j select-pane -D
          bind -N "Select pane above the active pane" k select-pane -U
          bind -N "Select pane to the right of the active pane" l select-pane -R

          bind -r -N "Resize the pane left by ${paneResizeAmount}" H resize-pane -L ${paneResizeAmount}
          bind -r -N "Resize the pane down by ${paneResizeAmount}" J resize-pane -D ${paneResizeAmount}
          bind -r -N "Resize the pane up by ${paneResizeAmount}" K resize-pane -U ${paneResizeAmount}
          bind -r -N "Resize the pane right by ${paneResizeAmount}" L resize-pane -R ${paneResizeAmount}

          unbind C-b
          set -g prefix C-a
          bind -N "Send the prefix key through to the application" C-a send-prefix
          bind C-a last-window

          bind q last-window
          bind w choose-tree -Zs
          bind ` switch-client -l

          bind s split-window -v -c '#{pane_current_path}'
          bind v split-window -h -c '#{pane_current_path}'

          bind -T copy-mode-vi v send-keys -X begin-selection
          bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"

          # toggle mouse on/off
          bind-key m \
            set-option -gF mouse "#{?mouse,off,on}" \;\
            display-message "#{?mouse,Mouse: ON,Mouse: OFF}"
          set -g mouse on

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

          # plugins
          ${(lib.concatMapStringsSep "\n\n" importPlugin plugins)}
        '';
      }
    ))

    (lib.mkIf cfg.tmuxinator.enable (
      let
        tmuxinator = "${pkgs.tmuxinator}/bin/tmuxinator";

      in
      {
        home.packages = [ pkgs.tmuxinator ];

        programs.zsh.shellAliases = {
          mux = tmuxinator;
          muxinate = "${tmuxinator} start project -n $(echo $(basename $PWD) | tr .: _)";
        };

        xdg.configFile."tmuxinator/project.yml".source = ./project.yml;
      }
    ))
  ];
}

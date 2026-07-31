{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ddd.programs.tmux;

  tmux = "${pkgs.tmux}/bin/tmux";
  tmuxinator = "${pkgs.unstable.tmuxinator}/bin/tmuxinator";

  paneResizeAmount = "5";
  plugins = with pkgs.tmuxPlugins; [ gruvbox ];

  attention = pkgs.writeShellScript "tmux-attention" ''
    export LC_ALL=C

    is_decimal() {
      case "$1" in
        ""|*[!0-9]*) return 1 ;;
        *) return 0 ;;
      esac
    }

    marker_path_for() {
      local socket_path="$1"
      local server_pid="$2"
      local pane_id="$3"
      local pane_number

      [ -n "$socket_path" ] || return 1
      is_decimal "$server_pid" || return 1

      case "$pane_id" in
        %*) pane_number="''${pane_id#%}" ;;
        *) return 1 ;;
      esac
      is_decimal "$pane_number" || return 1

      printf '%s.tmux-attention-v1-%s-%s' "$socket_path" "$server_pid" "$pane_number"
    }

    marker_is_valid() {
      local marker_path="$1"
      local marker_metadata

      if [ -L "$marker_path" ] || [ ! -f "$marker_path" ]; then
        return 1
      fi

      marker_metadata="$(${pkgs.coreutils}/bin/stat -c '%u:%a' -- "$marker_path" 2>/dev/null)" || return 1
      [ "$marker_metadata" = "$UID:600" ]
    }

    pane_status() {
      local socket_path="$1"
      local server_pid="$2"
      local pane_id="$3"
      local pane_index="$4"
      local marker_path

      is_decimal "$pane_index" || return 0
      marker_path="$(marker_path_for "$socket_path" "$server_pid" "$pane_id")" || return 0
      marker_is_valid "$marker_path" || return 0

      printf ' ⚑P%s' "$pane_index"
    }

    snapshot_tmp_dir=
    cleanup_snapshot() {
      if [ -n "$snapshot_tmp_dir" ]; then
        ${pkgs.coreutils}/bin/rm -rf -- "$snapshot_tmp_dir"
        snapshot_tmp_dir=
      fi
    }

    session_snapshot() {
      local socket_path="$1"
      local server_pid="$2"
      local memberships_file sessions_file attention_file
      local sorted_sessions_file sorted_attention_file
      local membership session_id session_number remainder window_index pane_id
      local marker_path current_session window_list

      [ -n "$socket_path" ] || return 1
      is_decimal "$server_pid" || return 1

      ${tmux} -S "$socket_path" set-option -s @pi_attention_snapshot_valid 0 || return 1

      snapshot_tmp_dir="$(${pkgs.coreutils}/bin/mktemp -d "''${TMPDIR:-/tmp}/tmux-attention.XXXXXXXXXX")" || return 1
      trap cleanup_snapshot EXIT
      trap 'cleanup_snapshot; exit 1' HUP INT TERM

      memberships_file="$snapshot_tmp_dir/memberships"
      sessions_file="$snapshot_tmp_dir/sessions"
      attention_file="$snapshot_tmp_dir/attention"
      sorted_sessions_file="$snapshot_tmp_dir/sessions.sorted"
      sorted_attention_file="$snapshot_tmp_dir/attention.sorted"
      : >"$sessions_file" || return 1
      : >"$attention_file" || return 1

      ${tmux} -S "$socket_path" list-panes -a \
        -F '#{session_id}|#{window_index}|#{pane_id}' \
        >"$memberships_file" || return 1

      while IFS= read -r membership || [ -n "$membership" ]; do
        case "$membership" in
          *'|'*'|'*) ;;
          *) return 1 ;;
        esac
        case "$membership" in
          *'|'*'|'*'|'*) return 1 ;;
        esac

        session_id="''${membership%%|*}"
        remainder="''${membership#*|}"
        window_index="''${remainder%%|*}"
        pane_id="''${remainder#*|}"

        case "$session_id" in
          \$*) session_number="''${session_id#\$}" ;;
          *) return 1 ;;
        esac
        is_decimal "$session_number" || return 1
        is_decimal "$window_index" || return 1

        marker_path="$(marker_path_for "$socket_path" "$server_pid" "$pane_id")" || return 1
        printf '%s\n' "$session_id" >>"$sessions_file" || return 1
        if marker_is_valid "$marker_path"; then
          printf '%s|%s\n' "$session_id" "$window_index" >>"$attention_file" || return 1
        fi
      done <"$memberships_file"

      ${pkgs.coreutils}/bin/sort -u "$sessions_file" >"$sorted_sessions_file" || return 1
      ${pkgs.coreutils}/bin/sort -t '|' -k1,1 -k2,2n -u \
        "$attention_file" >"$sorted_attention_file" || return 1

      while IFS= read -r session_id; do
        ${tmux} -S "$socket_path" set-option -t "$session_id" \
          @pi_attention_windows "" || return 1
      done <"$sorted_sessions_file"

      current_session=
      window_list=
      while IFS='|' read -r session_id window_index; do
        if [ "$session_id" != "$current_session" ]; then
          if [ -n "$current_session" ]; then
            ${tmux} -S "$socket_path" set-option -t "$current_session" \
              @pi_attention_windows "$window_list" || return 1
          fi
          current_session="$session_id"
          window_list="W$window_index"
        else
          window_list="$window_list,W$window_index"
        fi
      done <"$sorted_attention_file"

      if [ -n "$current_session" ]; then
        ${tmux} -S "$socket_path" set-option -t "$current_session" \
          @pi_attention_windows "$window_list" || return 1
      fi

      ${tmux} -S "$socket_path" set-option -s @pi_attention_snapshot_valid 1 || return 1
      cleanup_snapshot
      trap - EXIT HUP INT TERM
    }

    case "$1" in
      pane-status)
        shift
        pane_status "$@"
        ;;
      session-snapshot)
        shift
        session_snapshot "$@" >/dev/null 2>&1 || true
        ;;
    esac
  '';

  attentionStatusFormat = "#{P:#(${attention} pane-status #{q:socket_path} #{pid} #{q:pane_id} #{pane_index})}";

  chooseTreeFormat = lib.concatStrings [
    "#{?pane_format,"
    "#{?pane_marked,#[reverse],}"
    "#{pane_current_command}#{?pane_active,*,}#{?pane_marked,M,}"
    "#{?#{&&:#{pane_title},#{!=:#{pane_title},#{host_short}}},: \"#{pane_title}\",}"
    ",window_format,"
    "#{?window_marked_flag,#[reverse],}"
    "#{window_name}#{window_flags}"
    "#{?#{&&:#{==:#{window_panes},1},#{&&:#{pane_title},#{!=:#{pane_title},#{host_short}}}},: \"#{pane_title}\",}"
    ","
    "#{session_windows} windows"
    "#{?session_grouped, (group #{session_group}: #{session_group_list}),}"
    "#{?session_attached, (attached),}"
    "#{?#{&&:#{@pi_attention_snapshot_valid},#{@pi_attention_windows}}, ⚑ #{@pi_attention_windows},}"
    "}"
  ];

  importPlugin = p: ''
    # ${if lib.types.package.check p then p.pname else p.plugin.pname}
    ${p.extraConfig or ""}
    run-shell ${if lib.types.package.check p then p.rtp else p.plugin.rtp}
  '';

  tmuxCfg = ''
    # tmux-sensible
    run-shell ${pkgs.tmuxPlugins.sensible.rtp}

    set -g default-terminal "tmux-256color"
    set -s extended-keys always
    set -s extended-keys-format csi-u
    set -g default-command ""
    setw -g aggressive-resize on

    set -g base-index 1
    setw -g pane-base-index 1
    set -g renumber-windows on

    set -g status-keys vi
    set -g mode-keys vi

    # highlight active pane
    set -g window-active-style 'fg=terminal,bg=terminal'
    set -g window-style 'fg=colour247,bg=colour236'

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
    bind w set-option -s @pi_attention_snapshot_valid 0 \; run-shell '${attention} session-snapshot #{q:socket_path} #{pid}' \; choose-tree -Zs -F '${chooseTreeFormat}'
    bind ` switch-client -l

    bind s split-window -v -c '#{pane_current_path}'
    bind v split-window -h -c '#{pane_current_path}'

    bind -T copy-mode-vi v send-keys -X begin-selection
    bind -T copy-mode-vi y send-keys -X copy-pipe "xclip -i -selection clipboard"
    bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe "xclip -i -selection clipboard"
    bind -T copy-mode-vi DoubleClick1Pane select-pane \; send-keys -X select-word \; run-shell -d 0.3 \; send-keys -X copy-pipe "xclip -i -selection clipboard"

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

    ${cfg.extraConfig}

    # plugins
    ${(lib.concatMapStringsSep "\n\n" importPlugin plugins)}

    # Attention markers. Keep this after plugins because gruvbox replaces
    # both window status formats when it loads.
    set -g status-interval 1
    set-window-option -ag window-status-format '${attentionStatusFormat}'
    set-window-option -ag window-status-current-format '${attentionStatusFormat}'
  '';

in
{
  options.ddd.programs.tmux = {
    enable = lib.mkEnableOption "tmux";
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional tmux configuration appended to tmux.conf.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.tmux
      pkgs.unstable.tmuxinator
    ];

    programs.zsh.shellAliases = {
      mux = tmuxinator;
      muxinate = "${tmuxinator} start project -n $(echo $(basename $PWD) | tr .: _)";
    };

    xdg.configFile."tmux/tmux.conf".text = tmuxCfg;
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

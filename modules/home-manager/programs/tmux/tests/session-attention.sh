#!/usr/bin/env bash
# shellcheck disable=SC2016 # Tmux IDs intentionally contain literal dollar signs.

set -u
set -o pipefail

failures=0

fail() {
  printf 'not ok - %s\n' "$1" >&2
  failures=$((failures + 1))
}

pass() {
  printf 'ok - %s\n' "$1"
}

assert_eq() {
  label="$1"
  expected="$2"
  actual="$3"

  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label (expected $(printf %q "$expected"), got $(printf %q "$actual"))"
  fi
}

assert_contains() {
  label="$1"
  haystack="$2"
  needle="$3"

  case "$haystack" in
    *"$needle"*) pass "$label" ;;
    *) fail "$label (missing $(printf %q "$needle"))" ;;
  esac
}

fatal() {
  printf 'Bail out! %s\n' "$1" >&2
  exit 1
}

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/../../../../.." && pwd)"

if [ -n "${HOME_CONFIG:-}" ]; then
  home_config="$HOME_CONFIG"
else
  case "$(uname -s):$(uname -m)" in
    Darwin:arm64) home_config=ddd-complyance ;;
    Linux:x86_64) home_config=ddd-pc ;;
    Linux:aarch64 | Linux:arm64) home_config=abra ;;
    *) fatal "set HOME_CONFIG to a native home configuration" ;;
  esac
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/tmux-attention-test.XXXXXX")" || fatal "could not create temporary directory"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

config_file="$tmp_dir/tmux.conf"
flake_attr="$repo_root#homeConfigurations.$home_config"

nix eval --raw "$flake_attr.config.xdg.configFile.\"tmux/tmux.conf\".text" >"$config_file" \
  || fatal "could not evaluate generated tmux.conf"

helper="$(grep -Eo '/nix/store/[a-z0-9]+-tmux-attention(-status)?' "$config_file" | head -n 1)"
[ -n "$helper" ] || fatal "could not find generated attention helper"
helper_drv="$(
  nix eval --json "$flake_attr.config.xdg.configFile.\"tmux/tmux.conf\".text" \
    --apply 'builtins.getContext' \
    | python3 -c 'import json, sys; print(next(path for path in json.load(sys.stdin) if path.endswith("-tmux-attention.drv")))'
)" || fatal "could not resolve generated attention helper derivation"
nix-store -r "$helper_drv" >/dev/null || fatal "could not realize generated attention helper"

fake_tmux="$tmp_dir/fake-tmux"
cat >"$fake_tmux" <<'FAKE_TMUX'
#!/usr/bin/env bash
set -u

state="${TMUX_ATTENTION_TEST_STATE:?}"

{
  separator=
  for argument in "$@"; do
    printf '%s%s' "$separator" "$argument"
    separator=$'\t'
  done
  printf '\n'
} >>"$state/calls"

[ "${1:-}" = "-S" ] || exit 64
shift 2
command="${1:-}"
shift || true

case "$command" in
  list-panes)
    [ ! -e "$state/fail-list" ] || exit 1
    cat "$state/memberships"
    ;;
  set-option)
    scope=session
    target=
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -q) shift ;;
        -s) scope=server; shift ;;
        -t) target="${2:-}"; shift 2 ;;
        --) shift; break ;;
        *) break ;;
      esac
    done

    option="${1:-}"
    value="${2:-}"
    if [ "$scope" = server ]; then
      [ "$option" = "@pi_attention_snapshot_valid" ] || exit 64
      [ "$(cat "$state/fail-target" 2>/dev/null || true)" != server ] || exit 1
      printf '%s' "$value" >"$state/valid"
    else
      case "$target" in
        \$[0-9]*) ;;
        *) exit 64 ;;
      esac
      [ "$option" = "@pi_attention_windows" ] || exit 64
      [ "$(cat "$state/fail-target" 2>/dev/null || true)" != "$target" ] || exit 1
      printf '%s' "$value" >"$state/session-${target#\$}"
    fi
    ;;
  *) exit 64 ;;
esac
FAKE_TMUX
chmod +x "$fake_tmux"

real_tmux="$(grep -Eo '/nix/store/[a-z0-9]+-tmux-[^/]+/bin/tmux' "$helper" | head -n 1 || true)"
helper_under_test="$tmp_dir/tmux-attention"
if [ -n "$real_tmux" ]; then
  REAL_TMUX="$real_tmux" FAKE_TMUX="$fake_tmux" python3 - "$helper" "$helper_under_test" <<'PY'
import os
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).read_text()
source = source.replace(os.environ["REAL_TMUX"], os.environ["FAKE_TMUX"])
pathlib.Path(sys.argv[2]).write_text(source)
PY
else
  cp "$helper" "$helper_under_test"
fi
chmod +x "$helper_under_test"

state="$tmp_dir/state"
mkdir "$state"
: >"$state/calls"
export TMUX_ATTENTION_TEST_STATE="$state"

socket_path="$tmp_dir/server"
server_pid=4242
memberships='$1|2|%100
$1|2|%101
$1|5|%102
$1|10|%103
$2|7|%100
$3|1|%104'
printf '%s\n' "$memberships" >"$state/memberships"

marker_path() {
  pane_number="${1#%}"
  printf '%s.tmux-attention-v1-%s-%s' "$socket_path" "$server_pid" "$pane_number"
}

clear_markers() {
  find "$tmp_dir" -maxdepth 1 -name 'server.tmux-attention-v1-*' -exec rm -rf {} +
}

session_value() {
  cat "$state/session-${1#\$}" 2>/dev/null || true
}

run_snapshot() {
  : >"$state/calls"
  rm -f "$state"/fail-list "$state"/fail-target
  printf '0' >"$state/valid"
  snapshot_output="$("$helper_under_test" session-snapshot "$socket_path" "$server_pid" 2>&1)"
  snapshot_status=$?
}

assert_snapshot_quiet() {
  assert_eq "$1 exits successfully" 0 "$snapshot_status"
  assert_eq "$1 prints no user-facing output" '' "$snapshot_output"
}

# A successful empty snapshot clears stale session values and opens the validity gate.
printf 'W99' >"$state/session-1"
printf 'W88' >"$state/session-2"
printf 'W77' >"$state/session-3"
clear_markers
run_snapshot
assert_snapshot_quiet 'empty snapshot'
assert_eq 'empty snapshot is valid' 1 "$(cat "$state/valid" 2>/dev/null || true)"
assert_eq 'empty snapshot clears session one' '' "$(session_value '$1')"
assert_eq 'empty snapshot clears session two' '' "$(session_value '$2')"
assert_eq 'empty snapshot clears session three' '' "$(session_value '$3')"

# Duplicate panes collapse to one window, indexes sort numerically, and a linked
# pane contributes under each session-local index.
for pane_id in %100 %101 %102 %103; do
  : >"$(marker_path "$pane_id")"
  chmod 600 "$(marker_path "$pane_id")"
done
run_snapshot
assert_snapshot_quiet 'populated snapshot'
assert_eq 'affected windows are unique and numerically sorted' 'W2,W5,W10' "$(session_value '$1')"
assert_eq 'linked window uses the second session local index' 'W7' "$(session_value '$2')"
assert_eq 'unaffected session remains empty' '' "$(session_value '$3')"
assert_eq 'populated snapshot is valid' 1 "$(cat "$state/valid" 2>/dev/null || true)"

if awk -F '\t' '
  $3 == "set-option" && $4 == "-t" && $6 == "@pi_attention_windows" {
    if ($7 == "") cleared[$5] = 1
    else if (!cleared["$1"] || !cleared["$2"] || !cleared["$3"]) exit 1
  }
  $3 == "set-option" && $4 == "-s" && $5 == "@pi_attention_snapshot_valid" && $6 == "1" {
    valid_line = NR
  }
  END {
    if (!valid_line || valid_line != NR) exit 1
  }
' "$state/calls"; then
  pass 'all stale values clear before publishing and validity is set last'
else
  fail 'all stale values clear before publishing and validity is set last'
fi

# Removing a marker recomputes rather than retaining the prior snapshot.
rm -f "$(marker_path %100)" "$(marker_path %101)"
run_snapshot
assert_eq 'next snapshot removes a cleared linked window' 'W5,W10' "$(session_value '$1')"
assert_eq 'next snapshot clears the linked session value' '' "$(session_value '$2')"

# Invalid marker modes, types, and symlinks are ignored.
clear_markers
: >"$(marker_path %102)"
chmod 644 "$(marker_path %102)"
mkdir "$(marker_path %103)"
: >"$tmp_dir/symlink-target"
chmod 600 "$tmp_dir/symlink-target"
ln -s "$tmp_dir/symlink-target" "$(marker_path %104)"
run_snapshot
assert_eq 'invalid markers do not affect session one' '' "$(session_value '$1')"
assert_eq 'invalid markers do not affect session three' '' "$(session_value '$3')"

# Pane status uses the same validator and retains its exact existing output.
clear_markers
: >"$(marker_path %100)"
chmod 600 "$(marker_path %100)"
pane_output="$("$helper_under_test" pane-status "$socket_path" "$server_pid" %100 3)"
assert_eq 'pane status output remains unchanged' ' ⚑P3' "$pane_output"
chmod 644 "$(marker_path %100)"
pane_output="$("$helper_under_test" pane-status "$socket_path" "$server_pid" %100 3)"
assert_eq 'pane status ignores an invalid marker' '' "$pane_output"

# Malformed enumeration and tmux failures retain a false validity gate.
printf '%s\n' '$1|2|%100|extra' >"$state/memberships"
printf 'WOLD' >"$state/session-1"
run_snapshot
assert_snapshot_quiet 'malformed snapshot'
assert_eq 'malformed snapshot remains invalid' 0 "$(cat "$state/valid")"
assert_eq 'malformed snapshot does not publish partial state' WOLD "$(session_value '$1')"

printf '%s\n' "$memberships" >"$state/memberships"
: >"$state/fail-list"
printf '0' >"$state/valid"
snapshot_output="$("$helper_under_test" session-snapshot "$socket_path" "$server_pid" 2>&1)"
snapshot_status=$?
assert_snapshot_quiet 'enumeration failure'
assert_eq 'enumeration failure remains invalid' 0 "$(cat "$state/valid")"

printf '%s' '$2' >"$state/fail-target"
printf '0' >"$state/valid"
: >"$state/calls"
snapshot_output="$("$helper_under_test" session-snapshot "$socket_path" "$server_pid" 2>&1)"
snapshot_status=$?
assert_snapshot_quiet 'option write failure'
assert_eq 'option write failure remains invalid' 0 "$(cat "$state/valid")"

# The generated Prefix+w binding must run the snapshot synchronously before the
# chooser, and the copied tmux 3.6a pane/window branches must remain unchanged.
binding="$(grep '^bind w ' "$config_file" || true)"
assert_contains 'Prefix+w invalidates the previous snapshot' "$binding" 'set-option -s @pi_attention_snapshot_valid 0'
assert_contains 'Prefix+w runs the session snapshot helper' "$binding" 'session-snapshot #{q:socket_path} #{pid}'
assert_contains 'Prefix+w opens the collapsed zoomed chooser with a custom format' "$binding" 'choose-tree -Zs -F'

case "$binding" in
  *'set-option -s @pi_attention_snapshot_valid 0'*'run-shell '*'session-snapshot'*'choose-tree -Zs -F'*)
    pass 'Prefix+w commands are ordered invalidate, snapshot, chooser'
    ;;
  *) fail 'Prefix+w commands are ordered invalidate, snapshot, chooser' ;;
esac

choose_format="$(printf '%s\n' "$binding" | sed -n "s/.*choose-tree -Zs -F '\([^']*\)'.*/\1/p")"
expected_choose_format='#{?pane_format,#{?pane_marked,#[reverse],}#{pane_current_command}#{?pane_active,*,}#{?pane_marked,M,}#{?#{&&:#{pane_title},#{!=:#{pane_title},#{host_short}}},: "#{pane_title}",},window_format,#{?window_marked_flag,#[reverse],}#{window_name}#{window_flags}#{?#{&&:#{==:#{window_panes},1},#{&&:#{pane_title},#{!=:#{pane_title},#{host_short}}}},: "#{pane_title}",},#{session_windows} windows#{?session_grouped, (group #{session_group}: #{session_group_list}),}#{?session_attached, (attached),}#{?#{&&:#{@pi_attention_snapshot_valid},#{@pi_attention_windows}}, ⚑ #{@pi_attention_windows},}}'
assert_eq 'chooser format preserves tmux 3.6a pane and window text' "$expected_choose_format" "$choose_format"

window_status="$(grep '^set-window-option -ag window-status-format ' "$config_file" || true)"
assert_contains 'window status still invokes pane-status' "$window_status" 'tmux-attention pane-status #{q:socket_path} #{pid} #{q:pane_id} #{pane_index}'

if [ "$failures" -ne 0 ]; then
  printf '%s test(s) failed\n' "$failures" >&2
  exit 1
fi

printf 'All tmux session-attention tests passed.\n'

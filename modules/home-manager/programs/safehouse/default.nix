{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.safehouse;

  safehouse = pkgs.stdenvNoCC.mkDerivation {
    pname = "agent-safehouse";
    version = "0.10.1";

    src = pkgs.fetchurl {
      url = "https://github.com/eugene1g/agent-safehouse/releases/download/v0.10.1/safehouse.sh";
      hash = "sha256-vwboTXShHc2zzscpNyi3jfj3Cjz/3RletKyLhrUUJkI=";
    };

    dontUnpack = true;

    installPhase = ''
      install -Dm755 $src $out/bin/safehouse
    '';
  };

  safe = pkgs.writeShellScriptBin "safe" ''
    exec ${safehouse}/bin/safehouse --append-profile="$HOME/.config/safehouse/nix.sb" "$@"
  '';

  mkAgentWrapper = { name, command, commandArgs ? [ ], safehouseArgs ? [ ] }:
    pkgs.writeShellScriptBin name ''
      agent_browser_args="--no-sandbox"
      if [ -n "''${AGENT_BROWSER_ARGS:-}" ]; then
        agent_browser_args="$AGENT_BROWSER_ARGS,$agent_browser_args"
      fi

      safehouse_args=(${lib.escapeShellArgs safehouseArgs})
      agent_args=()
      safehouse_uses_full_env=0

      safehouse_has_feature() {
        local feature="$1"
        local expect_features=0
        local safehouse_arg
        local features

        for safehouse_arg in "''${safehouse_args[@]}"; do
          if [ "$expect_features" = 1 ]; then
            case ",$safehouse_arg," in
              *,"$feature",*) return 0 ;;
            esac
            expect_features=0
            continue
          fi

          case "$safehouse_arg" in
            --enable)
              expect_features=1
              ;;
            --enable=*)
              features="''${safehouse_arg#--enable=}"
              case ",$features," in
                *,"$feature",*) return 0 ;;
              esac
              ;;
          esac
        done

        return 1
      }

      for safehouse_arg in "''${safehouse_args[@]}"; do
        if [ "$safehouse_arg" = "--env" ]; then
          safehouse_uses_full_env=1
          break
        fi
      done

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --safehouse)
            shift
            while [ "$#" -gt 0 ]; do
              if [ "$1" = "--" ]; then
                shift
                break
              fi
              if [ "$1" = "--env" ]; then
                safehouse_uses_full_env=1
              fi
              safehouse_args+=("$1")
              shift
            done
            ;;
          *)
            agent_args+=("$1")
            shift
            ;;
        esac
      done

      if safehouse_has_feature docker; then
        safehouse_args+=("--add-dirs-ro=/Applications/OrbStack.app/Contents/MacOS/xbin")
      fi

      if [ "''${APP_SANDBOX_CONTAINER_ID:-}" = "agent-safehouse" ]; then
        export AGENT_BROWSER_ARGS="$agent_browser_args"
        exec "${command}" ${lib.escapeShellArgs commandArgs} "''${agent_args[@]}"
      fi

      if [ "$safehouse_uses_full_env" != 1 ]; then
        safehouse_args=("--env-pass=TMUX,TMUX_PANE" "''${safehouse_args[@]}")
      fi

      exec ${safe}/bin/safe \
        --enable=agent-browser,clipboard,process-control \
        "''${safehouse_args[@]}" \
        -- \
        "AGENT_BROWSER_ARGS=$agent_browser_args" \
        "${command}" \
        ${lib.escapeShellArgs commandArgs} \
        "''${agent_args[@]}"
    '';

  claude = mkAgentWrapper {
    name = "claude";
    command = "$HOME/.local/bin/claude";
    commandArgs = [ "--dangerously-skip-permissions" ];
  };

  codex = mkAgentWrapper {
    name = "codex";
    command = "$HOME/.cache/.bun/bin/codex";
    commandArgs = [ "--dangerously-bypass-approvals-and-sandbox" ];
  };

  opencode = mkAgentWrapper {
    name = "opencode";
    command = "$HOME/.cache/.bun/bin/opencode";
    commandArgs = [ "--auto" ];
  };

  pi = mkAgentWrapper {
    name = "pi";
    command = "$HOME/.cache/.bun/bin/pi";
    safehouseArgs = [
      "--enable=keychain"
      "--append-profile=${config.xdg.configHome}/safehouse/pi-codex-app-server.sb"
      "--add-dirs-ro=${config.home.homeDirectory}/dev/dddenis/pi-extensions"
    ];
  };

in
{
  options.ddd.programs.safehouse.enable = lib.mkEnableOption "agent-safehouse";

  config = lib.mkIf cfg.enable {
    home.packages = [ safehouse safe claude codex opencode pi ];

    xdg.configFile."safehouse/nix.sb".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.configPath}/modules/home-manager/programs/safehouse/nix.sb";

    xdg.configFile."safehouse/pi-codex-app-server.sb".text = ''
      ;; Pi's custom-footer extension spawns `codex app-server`
      ;; to read ChatGPT/Codex subscription usage. The spawned Codex process
      ;; inherits Pi's sandbox profile, so grant only the Codex state/config
      ;; paths it needs here. macOS Security/Trust access is supplied by
      ;; --enable=keychain on the pi wrapper.
      (allow file-read* file-write*
          (home-subpath "/.codex")
          (home-subpath "/.cache/codex")
      )

      (allow file-read*
          (home-literal "/Library/Preferences/com.openai.codex.plist")
          (literal "/Library/Preferences/com.openai.codex.plist")
          (literal "/Library/Managed Preferences/com.openai.codex.plist")
          (subpath "/etc/codex")
      )
    '';
  };
}

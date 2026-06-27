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

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --safehouse)
            shift
            while [ "$#" -gt 0 ]; do
              if [ "$1" = "--" ]; then
                shift
                break
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

  pi = mkAgentWrapper {
    name = "pi";
    command = "$HOME/.cache/.bun/bin/pi";
    safehouseArgs = [
      "--enable=keychain"
      "--append-profile=${config.xdg.configHome}/safehouse/pi-codex-app-server.sb"
    ];
  };

in
{
  options.ddd.programs.safehouse.enable = lib.mkEnableOption "agent-safehouse";

  config = lib.mkIf cfg.enable {
    home.packages = [ safehouse safe claude codex pi ];

    xdg.configFile."safehouse/nix.sb".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.configPath}/modules/home-manager/programs/safehouse/nix.sb";

    xdg.configFile."safehouse/pi-codex-app-server.sb".text = ''
      ;; Pi's openai-limits-statusline extension spawns `codex app-server`
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

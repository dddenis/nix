{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.safehouse;

  safehouse = pkgs.stdenvNoCC.mkDerivation {
    pname = "agent-safehouse";
    version = "0.9.0";

    src = pkgs.fetchurl {
      url = "https://github.com/eugene1g/agent-safehouse/releases/download/v0.9.0/safehouse.sh";
      hash = "sha256-YcL3HuE++QiUQssTzwUMxnnnZ+xI2pdx59j4o+sqhpc=";
    };

    dontUnpack = true;

    installPhase = ''
      install -Dm755 $src $out/bin/safehouse
    '';
  };

  safe = pkgs.writeShellScriptBin "safe" ''
    exec ${safehouse}/bin/safehouse --append-profile="$HOME/.config/safehouse/nix.sb" "$@"
  '';

  mkAgentWrapper = { name, command, commandArgs }:
    pkgs.writeShellScriptBin name ''
      agent_browser_args="--no-sandbox"
      if [ -n "''${AGENT_BROWSER_ARGS:-}" ]; then
        agent_browser_args="$AGENT_BROWSER_ARGS,$agent_browser_args"
      fi

      safehouse_args=()
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
        --enable=agent-browser,clipboard \
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

in
{
  options.ddd.programs.safehouse.enable = lib.mkEnableOption "agent-safehouse";

  config = lib.mkIf cfg.enable {
    home.packages = [ safehouse safe claude codex ];

    xdg.configFile."safehouse/nix.sb".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.configPath}/modules/home-manager/programs/safehouse/nix.sb";
  };
}

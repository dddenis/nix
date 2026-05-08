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

  claude = pkgs.writeShellScriptBin "claude" ''
    exec ${safe}/bin/safe --enable=clipboard "$HOME/.local/bin/claude" --dangerously-skip-permissions "$@"
  '';

  codex = pkgs.writeShellScriptBin "codex" ''
    exec ${safe}/bin/safe --enable=clipboard "$HOME/.cache/.bun/bin/codex" --dangerously-bypass-approvals-and-sandbox "$@"
  '';

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

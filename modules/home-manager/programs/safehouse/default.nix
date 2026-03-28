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

in
{
  options.ddd.programs.safehouse.enable = lib.mkEnableOption "agent-safehouse";

  config = lib.mkIf cfg.enable {
    home.packages = [ safehouse ];

    xdg.configFile."safehouse/nix.sb".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.configPath}/modules/home-manager/programs/safehouse/nix.sb";

    programs.zsh.shellAliases.safe = "safehouse --append-profile=~/.config/safehouse/nix.sb";
    programs.zsh.shellAliases.claude = "safe claude --dangerously-skip-permissions";
  };
}

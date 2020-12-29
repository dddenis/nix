{ config, lib, pkgs, ... }:

let
  cfg = config.programs.nnn;
  nnnConfigHome = "${config.xdg.configHome}/nnn";

  customPlugins = [ ./symlink2file.sh ];

  nnnPlugins = ''
    PLUGINS="${nnnConfigHome}/plugins";
    mkdir -p $PLUGINS

    for file in $(find "${pkgs.nnn.src}/plugins" -type f -maxdepth 1 ! -iname "*.md"); do
      ln -fs "$file" "${nnnConfigHome}/plugins"
    done
  '';

  quitcd = pkgs.substituteAll {
    name = "n";
    src = ./quitcd.sh;
    isExecutable = true;

    configHome = nnnConfigHome;
    nnn = "${pkgs.nnn}/bin/nnn";
  };

in {
  options.programs.nnn.enable' = lib.mkEnableOption "nnn";

  config = lib.mkIf cfg.enable' {
    home = {
      packages = with pkgs; [ atool file nnn tree unzip ];
      sessionVariables = {
        NNN_OPTS = "HUadou";
        NNN_PLUG = "L:symlink2file;p:preview-tui";
      };
      activation.nnnPlugins =
        lib.hm.dag.entryAfter [ "writeBoundary" ] nnnPlugins;
    };

    programs.zsh.initExtra = ''
      . ${quitcd}
    '';

    xdg.configFile = builtins.listToAttrs (map (source:
      lib.nameValuePair
      ("nnn/plugins/" + (lib.removeSuffix ".sh" (baseNameOf source))) {
        inherit source;
        executable = true;
      }) customPlugins);
  };
}

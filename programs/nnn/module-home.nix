{ config, lib, pkgs, ... }:

let
  cfg = config.programs.nnn;
  nnnConfigHome = "${config.xdg.configHome}/nnn";

  pluginsConfig = {
    L = "symlink2file";
    b = "bookmarks";
    p = "preview-tui";
  };

  customPlugins = [ ./symlink2file.sh ];

  nnnBookmarks = ''
    BOOKMARKS="${config.xdg.cacheHome}/nnn/bookmarks"
    rm -rf $BOOKMARKS
    mkdir -p $BOOKMARKS

    ${lib.concatStrings (lib.mapAttrsToList (name: path: ''
      ln -fs "${path}" "$BOOKMARKS/${name}"
    '') config.home.bookmarks)}
  '';

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
        NNN_PLUG = lib.concatStringsSep ";"
          (lib.mapAttrsToList (key: plugin: "${key}:${plugin}") pluginsConfig);
      };
      activation.nnn =
        lib.hm.dag.entryAfter [ "writeBoundary" ] (nnnBookmarks + nnnPlugins);
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

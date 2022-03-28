{ config, inputs, lib, pkgs, ... }:

let
  cfg = config.programs.nnn;
  nnnConfigHome = "${config.hm.xdg.configHome}/nnn";

  pluginsConfig = {
    P = "fzcd";
    b = "bookmarks";
    d = "diffs";
    l = "preview-tui";
    p = "fzopen";
  };

  customPlugins = [ ./symlink2file.sh ];

  nnnBookmarks = ''
    BOOKMARKS="${config.hm.xdg.cacheHome}/nnn/bookmarks"
    rm -rf "$BOOKMARKS"
    mkdir -p "$BOOKMARKS"

    ${lib.concatStrings (lib.mapAttrsToList (name: path: ''
      ln -fs "${path}" "$BOOKMARKS/${name}"
    '') config.home.bookmarks)}
  '';

  nnnPlugins = ''
    PLUGINS="${nnnConfigHome}/plugins";
    mkdir -p "$PLUGINS"

    for file in $(find "${pkgs.nnn.src}/plugins" -maxdepth 1 -type f ! -iname "*.md"); do
      if [[ "$file" == *".nnn-plugin-helper" ]]; then
        HELPER_PATH="$PLUGINS/$(basename "$file")"
        cp --remove-destination "$file" "$HELPER_PATH"
        chmod 644 "$HELPER_PATH"
        echo export CUR_CTX=1 >> "$HELPER_PATH"
      else
        ln -fs "$file" "$PLUGINS"
      fi
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

  config = lib.mkMerge [
    (lib.mkIf cfg.enable' {
      hm.home = {
        packages = with pkgs; [ file nnn tree ];
        sessionVariables = {
          NNN_OPTS = "HUadou";
          NNN_PLUG = lib.concatStringsSep ";"
            (lib.mapAttrsToList (key: plugin: "${key}:${plugin}")
              pluginsConfig);
        };
        activation.nnn =
          inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ]
          (nnnBookmarks + nnnPlugins);
      };

      hm.programs.zsh.initExtra = ''
        . ${quitcd}
      '';

      hm.xdg.configFile = builtins.listToAttrs (map (source:
        lib.nameValuePair
        ("nnn/plugins/" + (lib.removeSuffix ".sh" (baseNameOf source))) {
          inherit source;
          executable = true;
        }) customPlugins);
    })

    (lib.mkIf config.programs.atool.enable' {
      hm.home.sessionVariables.NNN_ARCHIVE =
        "\\.(7z|a|ace|alz|arc|arj|bz|bz2|cab|cpio|deb|gz|jar|lha|lz|lzh|lzma|lzo|rar|rpm|rz|t7z|tar|tbz|tbz2|tgz|tlz|txz|tZ|tzo|war|xpi|xz|Z|zip)$";
    })
  ];
}

{ config, lib, nixosConfig, pkgs, ... }:

let
  cfg = config.xserver.desktopManager.plasma5;

  plasma5Config =
    lib.concatMapStrings writeConfigEntry (normalizeConfigs cfg.configs);

  normalizeConfigs = configs:
    let
      paths = lib.collect lib.isList
        (lib.mapAttrsRecursive (path: value: path ++ [ value ]) configs);
    in map normalizeConfigEntry paths;

  normalizeConfigEntry = entry: {
    file = "${config.xdg.configHome}/${builtins.head entry}";
    groups = lib.sublist 1 (builtins.length entry - 3) entry;
    key = lib.last (lib.init entry);
    value = lib.last entry;
  };

  writeConfigEntry = { file, groups, key, value }: ''
    $DRY_RUN_CMD ${pkgs.libsForQt5.kconfig}/bin/kwriteconfig5 \
      --file "${file}" \
      ${lib.concatMapStringsSep "\\n" (group: ''--group "${group}"'') groups} \
      --key "${key}" \
      "${if lib.isBool value then lib.boolToString value else toString value}"
  '';

in {
  options.xserver.desktopManager.plasma5 = {
    configs = lib.mkOption {
      type = with lib.types; attrsOf (attrs);
      default = { };
    };
  };

  config =
    lib.mkIf nixosConfig.services.xserver.desktopManager.plasma5.enable' {
      xserver.desktopManager.plasma5 = let statusBarHeight = 30;
      in {
        configs = {
          baloofilerc."Basic Settings".Indexing-Enabled = false;

          kcminputrc.Keyboard = {
            RepeatDelay = 225;
            RepeatRate = 33;
          };

          kdeglobals.KDE.SingleClick = false;

          kmserverrc.General = {
            confirmLogout = false;
            loginMode = "emptySession";
          };

          krunnerrc = {
            General.FreeFloating = true;

            Plugins = {
              CharacterRunnerEnabled = true;
              DictionaryEnabled = false;
              "Kill RunnerEnabled" = true;
              PowerDevilEnabled = false;
              "Spell CheckerEnabled" = false;
              baloosearchEnabled = false;
              bookmarksEnabled = false;
              browsertabsEnabled = false;
              calculatorEnabled = false;
              desktopsessionsEnabled = false;
              konsoleprofilesEnabled = false;
              krunner_appstreamEnabled = false;
              kwinEnabled = false;
              locationsEnabled = false;
              "org.kde.activitiesEnabled" = false;
              "org.kde.datetimeEnabled" = false;
              "org.kde.windowedwidgetsEnabled" = false;
              placesEnabled = true;
              plasma-desktopEnabled = false;
              recentdocumentsEnabled = false;
              servicesEnabled = true;
              shellEnabled = false;
              unitconverterEnabled = true;
              webshortcutsEnabled = false;
              windowsEnabled = false;
            };
          };

          kscreenlockerrc.Daemon.Autolock = false;

          "plasma-org.kde.plasma.desktop-appletsrc".Containments = {
            "1".General.ToolBoxButtonY = statusBarHeight;
            "2".location = 3;
            "7".location = 3;
          };

          plasmashellrc.PlasmaViews."Panel 2" = {
            Defaults.thickness = statusBarHeight;
            Horizontal1920.thickness = statusBarHeight;
          };
        };
      };

      xdg.configFile = {
        kglobalshortcutsrc.source = ./kglobalshortcutsrc;
        kwinrc.source = ./kwinrc;
        kwinrulesrc.source = ./kwinrulesrc;
        kxkbrc.source = ./kxkbrc;
      };

      xsession = {
        enable = true;
        scriptPath = ".xsession-hm";
        windowManager.command = "exec startplasma-x11";
      };

      home.activation.plasma5Config =
        lib.hm.dag.entryAfter [ "writeBoundary" ] plasma5Config;
    };
}

{ config, lib, nixosConfig, pkgs, ... }:

let
  inherit (lib.hm.gvariant) mkUint32;
  cfg = config.xserver.desktopManager.gnome;

in {
  options.xserver.desktopManager.gnome = {
    config = lib.mkOption {
      type = lib.types.path;
      default = ./dconf.ini;
    };
  };

  config = lib.mkIf nixosConfig.services.xserver.desktopManager.gnome.enable' {
    dconf.settings = {
      "org/gnome/desktop/interface" = {
        enable-hot-corners = false;
        text-scaling-factor = 0.85;
      };
      "org/gnome/desktop/peripherals/keyboard" = {
        delay = mkUint32 300;
        repeat-interval = mkUint32 40;
      };
      "org/gnome/desktop/session" = { idle-delay = mkUint32 0; };
      "org/gnome/desktop/wm/keybindings" = {
        activate-window-menu = [ ];
        close = [ "<Shift><Super>c" ];
        cycle-group = [ "<Alt>grave" ];
        cycle-group-backward = [ "<Shift><Alt>grave" ];
        move-to-workspace-1 = [ "<Shift><Super>exclam" ];
        move-to-workspace-2 = [ "<Shift><Super>at" ];
        move-to-workspace-3 = [ "<Shift><Super>numbersign" ];
        move-to-workspace-4 = [ "<Shift><Super>dollar" ];
        switch-applications = [ "<Alt>Tab" ];
        switch-applications-backward = [ "<Shift><Alt>Tab" ];
        switch-group = [ ];
        switch-group-backward = [ ];
        switch-input-source = [ "<Alt>space" "XF86Keyboard" ];
        switch-input-source-backward =
          [ "<Shift><Alt>space" "<Shift>XF86Keyboard" ];
        switch-to-workspace-1 = [ "<Super>1" ];
        switch-to-workspace-2 = [ "<Super>2" ];
        switch-to-workspace-3 = [ "<Super>3" ];
        switch-to-workspace-4 = [ "<Super>4" ];
        switch-to-workspace-left = [ "<Primary>Left" ];
        switch-to-workspace-right = [ "<Primary>Right" ];
        switch-windows = [ ];
        switch-windows-backward = [ ];
      };
      "org/gnome/mutter" = { overlay-key = ""; };
      "org/gnome/mutter/keybindings" = { switch-monitor = [ "XF86Display" ]; };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" =
        {
          binding = "<Primary><Alt>q";
          command = "systemctl suspend";
          name = "Suspend";
        };
      "org/gnome/settings-daemon/plugins/power" = {
        power-button-action = "interactive";
        sleep-inactive-ac-type = "nothing";
      };
      "org/gnome/shell" = {
        enabled-extensions = [
          "drive-menu@gnome-shell-extensions.gcampax.github.com"
          "instantworkspaceswitcher@amalantony.net"
          "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
          "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
        ];
        favorite-apps = [ ];
      };
      "org/gnome/shell/keybindings" = { toggle-overview = [ "<Super>space" ]; };
    };

    home.packages = with pkgs; [
      gnome.dconf-editor
      gnomeExtensions.appindicator
    ];
  };
}

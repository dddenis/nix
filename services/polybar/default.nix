{ config, lib, pkgs, ... }:

let
  cfg = config.services.polybar;

  package = pkgs.polybar.override { pulseSupport = true; };

  bg = config.theme.primary.background;
  bg-alt = config.theme.normal.black;
  fg = config.theme.primary.foreground;
  fg-alt = config.theme.bright.white;

in {
  options.services.polybar.enable' = lib.mkEnableOption "polybar";

  config = lib.mkIf cfg.enable' {
    fonts.fonts = with pkgs; [ iosevka-ddd-font iosevka-nerd-font ];

    services.polybar = {
      enable = true;
      inherit package;
      script = "${package}/bin/polybar xmonad &";

      config = {
        "bar/xmonad" = {
          monitor = "\${env:MONITOR:HDMI-1}";

          enable-ipc = true;

          width = "100%";
          height = "32";
          bottom = false;
          fixed-center = true;
          line-size = "2";

          background = bg;
          foreground = fg;

          font-0 = "Iosevka DDD Term:style=Extended:pixelsize=11;2";
          font-1 = "Iosevka DDD Term:style=Bold Extended:pixelsize=11;2";
          font-2 = "Iosevka Nerd Font:pixelsize=12;2";

          cursor-click = "pointer";
          cursor-scroll = "ns-resize";

          modules-left = "workspaces layout";
          modules-right = "date volume powermenu";
        };

        "module/workspaces" = {
          type = "custom/script";
          exec = "${pkgs.coreutils}/bin/tail -F /tmp/.xmonad-workspace-log";
          exec-if = "[ -p /tmp/.xmonad-workspace-log ]";
          tail = true;

          format = "<label>";
          format-background = bg-alt;
          format-foreground = config.theme.bright.black;
          format-padding = 2;
        };

        "module/layout" = {
          type = "custom/script";
          exec = "${pkgs.coreutils}/bin/tail -f /tmp/.xmonad-layout-log";
          exec-if = "[ -p /tmp/.xmonad-layout-log ]";
          tail = true;

          format = "<label>";
          format-background = bg-alt;
          format-foreground = fg-alt;
          format-padding = 1;

          label = "%output%  ";
        };

        "module/date" = {
          type = "internal/date";
          interval = 30;

          label = "%time%";
          label-padding = 2;
          label-background = bg;
          label-foreground = fg-alt;

          time = " %H:%M";
          time-alt = " %Y-%m-%d";
        };

        "module/volume" = {
          type = "internal/pulseaudio";

          format-volume = "<ramp-volume> <label-volume>  ";
          format-volume-padding = 2;
          format-volume-background = bg;
          format-volume-foreground = fg-alt;

          label-volume = "%percentage:3%%";
          label-muted = " mute  ";
          label-muted-foreground = "\${self.format-volume-foreground}";
          label-muted-background = "\${self.format-volume-background}";
          label-muted-padding = 2;

          ramp-volume-0 = "";
        };

        "module/lock" = {
          type = "custom/text";

          content = " ";
          content-padding = 2;
          content-background = bg-alt;
          content-foreground = fg-alt;

          click-left = "sleep 0.1; xdotool key Super q l";
        };

        "module/userswitch" = {
          type = "custom/text";

          content = "";
          content-padding = 2;
          content-background = bg-alt;
          content-foreground = fg-alt;

          click-left = "~/.scripts/switch";
        };

        "module/powermenu" = {
          type = "custom/text";

          content = "襤 ";
          content-padding = 2;
          content-background = bg-alt;
          content-foreground = fg-alt;

          click-left = "${pkgs.systemd}/bin/systemctl poweroff";
        };
      };
    };
  };
}

{ config, lib, pkgs, ... }:

let bookmarks = { vn = "/dev/dddenis/vn"; };

in {
  imports = [ ./hardware-configuration.nix ];

  boot.blacklistedKernelModules = [ "sp5100_tco" ];

  fonts.fontconfig.defaultFonts = {
    monospace =
      lib.mkBefore [ "Iosevka DDD Extended" "Iosevka Nerd Font Mono" ];
  };

  hardware = {
    bluetooth.enable = true;
    cpu.amd.updateMicrocode = true;
    opengl.driSupport32Bit = true;

    pulseaudio = {
      extraModules = [ pkgs.pulseaudio-modules-bt ];
      package = pkgs.pulseaudioFull;
    };
  };

  home-manager.users.ddd.home.bookmarks = builtins.mapAttrs
    (_: path: config.home-manager.users.ddd.home.homeDirectory + path)
    bookmarks;

  services = {
    safeeyes.enable = true;

    xserver = {
      enable = true;

      layout = "us,ru";
      xkbModel = "hhk";
      xkbOptions = "ctrl:nocaps,grp:alt_space_toggle";

      displayManager.sddm.enable = true;
      desktopManager.plasma5.enable = true;
    };
  };

  systemd.services.bluetooth.serviceConfig.ExecStart =
    [ "" "${pkgs.bluez}/bin/bluetoothd --noplugin=sap" ];

  time.timeZone = "Europe/Berlin";
}

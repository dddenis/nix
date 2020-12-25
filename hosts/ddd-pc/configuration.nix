{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.blacklistedKernelModules = [ "sp5100_tco" ];

  time.timeZone = "Europe/Berlin";

  hardware = {
    bluetooth.enable = true;
    cpu.amd.updateMicrocode = true;
    opengl.driSupport32Bit = true;

    pulseaudio = {
      extraModules = [ pkgs.pulseaudio-modules-bt ];
      package = pkgs.pulseaudioFull;
    };
  };

  fonts.fontconfig.defaultFonts = {
    monospace =
      lib.mkBefore [ "Iosevka DDD Extended" "Iosevka Nerd Font Mono" ];
  };

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
}

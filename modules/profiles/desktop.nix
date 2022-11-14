{ config, lib, ... }:

{
  options.profiles.desktop.enable = lib.mkEnableOption "desktop profile";

  config = lib.mkIf config.profiles.desktop.enable {
    profiles.shared.enable = true;

    boot.kernel.sysctl = { "vm.swappiness" = 60; };
    boot.loader.timeout = null;

    hardware.pulseaudio.enable = false;

    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}

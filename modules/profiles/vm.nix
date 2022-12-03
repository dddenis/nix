{ config, lib, ... }:

{
  options.profiles.vm.enable = lib.mkEnableOption "vm profile";

  config = lib.mkIf config.profiles.vm.enable {
    profiles.shared.enable = true;

    hardware.video.hidpi.enable = true;

    security.sudo.wheelNeedsPassword = false;

    networking.firewall.enable = false;

    environment.variables.GDK_DPI_SCALE = "0.75";

    users.mutableUsers = false;
    users.users.root.initialPassword = "root";

    home.enable' = true;

    hm.xresources.properties = { "Xft.dpi" = 288; };

    programs.ssh.extraConfig = ''
      AddKeysToAgent yes
    '';

    services.openssh.enable = true;

    services.xserver = {
      enable = true;
      dpi = 288;
      xkbOptions = "altwin:swap_alt_win";
      autoRepeatDelay = 220;
      autoRepeatInterval = 40;
      displayManager.autoLogin.user = config.user.name;
      displayManager.defaultSession = "none+i3";
      windowManager.i3.enable' = true;
    };
  };
}

{ config, lib, options, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ../../vm/vmware-guest.nix ];

  disabledModules = [ "virtualisation/vmware-guest.nix" ];

  profiles.shared.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_5_15;

  hardware.video.hidpi.enable = true;
  hardware.enableAllFirmware = true;

  security.sudo.wheelNeedsPassword = false;

  virtualisation.docker.enable = true;
  virtualisation.vmware.guest.enable = true;

  networking.interfaces.ens160.useDHCP = true;
  networking.firewall.enable = false;

  fileSystems."/host" = {
    fsType = "fuse./run/current-system/sw/bin/vmhgfs-fuse";
    device = ".host:/";
    options = [
      "umask=22"
      "uid=1000"
      "gid=1000"
      "allow_other"
      "auto_unmount"
      "defaults"
    ];
  };

  fileSystems."/proc/sys/fs/binfmt_misc" = {
    fsType = "binfmt_misc";
    device = "binfmt_misc";
  };

  fonts = {
    fonts = with pkgs; [ iosevka-ddd-font iosevka-nerd-font ];

    fontconfig.defaultFonts = {
      monospace = lib.mkBefore [ "Iosevka DDD" "Iosevka Nerd Font Mono" ];
    };
  };

  programs = {
    atool.enable' = true;
    bat.enable' = true;
    direnv.enable' = true;
    fzf.enable' = true;
    git.enable' = true;
    lazygit.enable' = true;
    less.enable' = true;
    nnn.enable' = true;
    psql.enable' = true;
    ripgrep.enable' = true;
    st.enable' = true;
    tmux.enable' = true;
    vim.enable' = true;
    zsh.enable' = true;
  };

  programs.ssh.extraConfig = ''
    AddKeysToAgent yes
  '';

  services.openssh.enable = true;
  services.xserver = {
    enable = true;
    xkbOptions = "altwin:swap_alt_win";
    desktopManager.wallpaper.mode = "scale";
    displayManager.autoLogin.user = config.user.name;
    displayManager.defaultSession = "none+i3";
    displayManager.sessionCommands = ''
      ${pkgs.xorg.xset}/bin/xset r rate 200 40
      ${pkgs.xorg.xrandr}/bin/xrandr -s '3840x2160'
    '';
    windowManager.i3.enable = true;
    windowManager.i3.configFile = ./i3-config;
  };

  users.mutableUsers = false;
  users.users.root.initialPassword = "root";

  user = {
    name = "ddd";
    initialPassword = "ddd";
    extraGroups = [ "docker" ];

    packages = with pkgs; [
      docker-compose
      fd
      firefox
      gnumake
      htop
      lazydocker
      ungoogled-chromium
      xclip
    ];
  };

  home.enable' = true;

  hm.home.sessionVariables = { GDK_DPI_SCALE = 0.75; };

  hm.programs = { git.userEmail = "denis.goncharenko@kontist.com"; };

  hm.xdg.mimeApps.defaultApplications = {
    "application/xhtml+xml" = "firefox.desktop";
    "text/html" = "firefox.desktop";
    "text/xml" = "firefox.desktop";
    "x-scheme-handler/ftp" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
  };
}

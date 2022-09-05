{ config, lib, pkgs, ... }:

{
  options.profiles.work.enable = lib.mkEnableOption "work profile";

  config = lib.mkIf config.profiles.work.enable {
    virtualisation.docker.enable = true;

    user = {
      name = "ddd";
      initialPassword = "ddd";
      extraGroups = [ "docker" ];

      packages = with pkgs; [
        awscli2
        docker-compose
        fd
        firefox
        gnumake
        htop
        jq
        lazydocker
        xclip
      ];
    };

    fonts = {
      fonts = with pkgs; [ iosevka-ddd-font iosevka-nerd-font ];
      fontconfig.defaultFonts.monospace =
        lib.mkBefore [ "Iosevka DDD" "Iosevka Nerd Font Mono" ];
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

    hm.programs = { git.userEmail = "denis.goncharenko@kontist.com"; };
  };
}

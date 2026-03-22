{ pkgs, ... }:

{
  profiles.gui.enable = true;

  home.username = "ddd";

  home.packages = with pkgs; [
    _1password-cli
  ];

  ddd.hosts = {
    abra.enable = true;
  };

  ddd.services.cloudflare-tunnel = {
    enable = true;
    tunnelId = "56755755-2d2f-4b90-9afa-542259b10ed6";
  };

  programs.git.includes = [
    {
      condition = "hasconfig:remote.*.url:git@github.com:complyance/**";
      contents = {
        user.email = "denis.goncharenko@complyance.com";
      };
    }
  ];

  sops.defaultSopsFile = ./secrets.yaml;
}

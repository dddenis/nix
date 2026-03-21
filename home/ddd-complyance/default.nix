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

{
  profiles.gui.enable = true;

  home.username = "ddd";

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

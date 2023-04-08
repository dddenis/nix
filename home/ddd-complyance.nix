{
  home.username = "ddd";
  home.homeDirectory = "/Users/ddd";

  programs.git.includes = [
    {
      condition = "hasconfig:remote.*.url:git@github.com:complyance/**";
      contents = {
        user.email = "denis.goncharenko@complyance.com";
      };
    }
  ];
}

{
  config = {
    programs.nix-index.enable = true;

    programs.readline.enable = true;
    programs.readline.variables = { editing-mode = "vi"; };
  };
}

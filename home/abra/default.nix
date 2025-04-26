{ pkgs, ... }:

{
  home.username = "ddd";

  home.packages = with pkgs; [
    wezterm.terminfo
  ];
}

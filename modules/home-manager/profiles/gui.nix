{ config, lib, ... }:

{
  options.profiles.gui.enable = lib.mkEnableOption "gui profile";

  config = lib.mkIf config.profiles.gui.enable {
    ddd.programs = {
      wezterm.enable = true;
    };
  };
}

{ config, lib, pkgs, ... }:

let
  cfg = config.programs.lazygit;
  yamlFormat = pkgs.formats.yaml { };

in {
  config = lib.mkIf cfg.enable' {
    xdg.configFile."lazygit/config.yml".source =
      yamlFormat.generate "lazygit-config" cfg.settings;
  };
}

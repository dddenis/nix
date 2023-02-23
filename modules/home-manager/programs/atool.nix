{ config, lib, pkgs, ... }:

let cfg = config.ddd.programs.atool;

in
{
  options.ddd.programs.atool.enable = lib.mkEnableOption "atool";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ atool file p7zip unrar unzip ];
  };
}

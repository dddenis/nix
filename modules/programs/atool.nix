{ config, lib, pkgs, ... }:

let cfg = config.programs.atool;

in {
  options.programs.atool.enable' = lib.mkEnableOption "atool";

  config = lib.mkIf cfg.enable' {
    hm.home.packages = with pkgs; [ atool file p7zip unrar unzip ];
  };
}

{ config, lib, pkgs, ... }:

let cfg = config.ddd.programs.atuin;

in
{
  options.ddd.programs.atuin.enable = lib.mkEnableOption "atuin";

  config = lib.mkIf cfg.enable {
    programs.atuin = {
      enable = true;

      flags = [
        "--disable-up-arrow"
      ];

      settings = {
        sync_address = "https://atuin.mrbl.io";
        key_path = config.sops.secrets."atuin/key".path;
        inline_height = 20;
        sync.records = true;
      };
    };

    sops.secrets."atuin/key" = { };
  };
}

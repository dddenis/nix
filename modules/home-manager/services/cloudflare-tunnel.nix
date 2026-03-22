{ config, lib, pkgs, ... }:

let cfg = config.ddd.services.cloudflare-tunnel;

in
{
  options.ddd.services.cloudflare-tunnel = {
    enable = lib.mkEnableOption "Cloudflare Tunnel";

    tunnelId = lib.mkOption {
      type = lib.types.str;
      description = "The Cloudflare Tunnel ID.";
    };

    originUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:4200";
      description = "The local URL to proxy traffic to.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.cloudflared ];

    sops.secrets."cloudflare-tunnel/credentials" = {
      path = "${config.home.homeDirectory}/.cloudflared/${cfg.tunnelId}.json";
    };

    home.file.".cloudflared/config.yml".text = ''
      tunnel: ${cfg.tunnelId}
      credentials-file: ${config.sops.secrets."cloudflare-tunnel/credentials".path}
      url: ${cfg.originUrl}
    '';
  };
}

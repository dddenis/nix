{ config, lib, pkgs, ... }:

let cfg = config.ddd.hosts.abra;

in
{
  options.ddd.hosts.abra.enable = lib.mkEnableOption "abra";

  config = lib.mkIf cfg.enable {
    nix.buildMachines = [
      {
        hostName = "abra";
        systems = [ "aarch64-linux" ];
        protocol = "ssh-ng";
        sshUser = "builder";
        sshKey = config.sops.secrets."ssh/keys/builder@ddd-complyance".path;
      }
    ];
    sops.secrets."ssh/keys/builder@ddd-complyance" = { };

    programs.ssh.includes = [
      config.sops.secrets."ssh/includes/abra".path
    ];

    programs.zsh.shellAliases = {
      abra = "ssh abra -t tmux a";
    };

    sops.secrets."ssh/includes/abra".path = "${config.home.homeDirectory}/.ssh/includes/abra";
  };
}

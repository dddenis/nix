{ config, lib, pkgs, ... }:

let cfg = config.ddd.programs.ssh;

in
{
  options.ddd.programs.ssh.enable = lib.mkEnableOption "ssh";

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings."*" = {
        ForwardAgent = false;
        AddKeysToAgent = "yes";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        IdentityFile = "~/.ssh/id_ed25519";
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };

      extraConfig = lib.mkIf pkgs.stdenv.isDarwin ''
        UseKeychain yes
      '';
    };
  };
}

{ config, lib, pkgs, ... }:

let cfg = config.ddd.programs.ssh;

in
{
  options.ddd.programs.ssh.enable = lib.mkEnableOption "ssh";

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      matchBlocks."*" = {
        forwardAgent = false;
        addKeysToAgent = "yes";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        identityFile = "~/.ssh/id_ed25519";
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };

      extraConfig = lib.mkIf pkgs.stdenv.isDarwin ''
        UseKeychain yes
      '';
    };
  };
}

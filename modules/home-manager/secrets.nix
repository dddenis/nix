{ config, inputs, ... }:

{
  imports = [
    inputs.sops-nix.homeManagerModule
    inputs.tmux.homeManagerModule
  ];

  sops.age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
}

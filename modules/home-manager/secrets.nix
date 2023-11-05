{ config, inputs, ... }:

{
  imports = [
    inputs.sops-nix.homeManagerModule
  ];

  sops.age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
}

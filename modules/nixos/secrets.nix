{ inputs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops.age.keyFile = "/var/lib/sops/age/keys.txt";
}

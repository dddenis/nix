{ inputs, ... }:

{
  imports = [
    inputs.kmonad.nixosModules.default

    ./hosts
    ./profiles
    ./services

    ./secrets.nix
  ];
}

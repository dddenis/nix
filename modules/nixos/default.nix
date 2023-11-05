{ inputs, ... }:

{
  imports = [
    inputs.kmonad.nixosModules.default

    ./profiles
    ./services

    ./secrets.nix
  ];
}

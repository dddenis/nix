{ inputs, ... }:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.kmonad.nixosModules.default

    ./profiles
    ./services
  ];
}

{ inputs, ... }:

{
  imports = [
    inputs.kmonad.nixosModules.default

    ./profiles
    ./services
  ];
}

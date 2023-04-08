{ inputs, ... }:

{
  imports = [
    inputs.neovim.nixosModules.neovim

    ./home
    ./misc
    ./profiles
    ./programs
    ./services
    ./theme
  ];
}

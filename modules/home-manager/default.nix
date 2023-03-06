{ inputs, ... }:

{
  imports = [
    inputs.neovim.nixosModules.neovim

    ./home
    ./profiles
    ./programs
    ./services
    ./theme
  ];
}

self: super:

let
  iosevka = super.callPackage ./iosevka.nix {};

in {
  iosevka-ddd-font = iosevka.ddd;
  iosevka-nerd-font = iosevka.nerd;
}

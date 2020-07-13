self: super:

let
  iosevka = super.callPackage ./iosevka.nix {};

in {
  iosevka-ddd-font = iosevka.ddd;
  iosevka-ddd-term-font = iosevka.ddd-term;
  iosevka-nerd-font = iosevka.nerd;

  meslo-lgs-nf = super.callPackage ./meslo-lgs-nf.nix { };
}

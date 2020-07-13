self: super:

{
  unityhub = super.callPackage ./unityhub.nix { };
  unity-androidenv = super.callPackage ./androidenv.nix { };
}

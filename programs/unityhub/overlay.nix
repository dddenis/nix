self: super:

{
  unity-androidenv = super.callPackage ./androidenv.nix { };
  unityhub = super.callPackage ./unityhub.nix { };
}

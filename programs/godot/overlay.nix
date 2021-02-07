self: super:

let
  inherit (import ./utils.nix) mkManifest;

  sharedManifest = {
    v = "3.2.4";
    release = "rc1";
  };

in {
  godot = super.callPackage ./godot.nix {
    manifest = mkManifest (sharedManifest // {
      sha256 = "MfsP2r/N6pZSp5+ij1lJv+PFqtWBQOlxIJsWbhFBcRM=";
    });
  };

  godot-mono = super.callPackage ./godot-mono.nix {
    manifest = mkManifest (sharedManifest // {
      mono = true;
      sha256 = "n6W+3H1h33oonjOmWvS7r8fuUJmdTN/BgxBFAV4XBlU=";
    });
  };
}

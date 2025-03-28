{ pkgs ? import <nixpkgs> {
    overlays = [
      (_: prev: {
        nodejs = prev.nodejs_22;
      })
    ];
  }
}:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    nodejs
  ];
}

{ pkgs ? import <nixpkgs> {
    overlays = [
      (_: prev: {
        nodejs = prev.nodejs-18_x;
      })
    ];
  }
}:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    nodejs
  ];
}

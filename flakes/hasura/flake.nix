{
  inputs = {
    hasura.url = "github:hasura/graphql-engine/v2.20.0";
    hasura.flake = false;

    nhost.url = "github:nhost/cli/v0.8.24";
    nhost.flake = false;
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
    ({
      overlays.default = _: prev: {
        inherit (self.packages."${prev.stdenv.hostPlatform.system}")
          hasura-cli-ext
          hasura-cli
          nhost-cli;
      };
    }
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };

      in
      {
        packages = {
          hasura-cli-ext = pkgs.callPackage ./hasura-cli-ext.nix {
            src = inputs.hasura;
          };

          hasura-cli = pkgs.callPackage ./hasura-cli.nix {
            src = inputs.hasura;
          };

          nhost-cli = pkgs.callPackage ./nhost-cli.nix {
            src = inputs.nhost;
          };
        };
      })
    );
}

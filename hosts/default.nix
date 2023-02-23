{ inputs, outputs }:

let
  inherit (outputs) lib;

  systemConfigs = {
    x86_64-linux = [
      ./ddd-pc/default.nix
    ];
  };

  nixosSystems = systemConfigs:
    let
      allSystems =
        lib.mapAttrsToList
          (system: hostConfigs: map (nixosSystem system) hostConfigs)
          systemConfigs;
    in
    builtins.listToAttrs (lib.flatten allSystems);

  nixosSystem = system: hostConfig:
    let hostName = toString (lib.baseDirOf hostConfig);

    in
    lib.nameValuePair hostName (inputs.nixos.lib.nixosSystem {
      inherit system;

      specialArgs = { inherit lib; };

      modules = [
        inputs.nixos.nixosModules.notDetected
        inputs.home-manager.nixosModules.home-manager
        inputs.kmonad.nixosModules.default
        outputs.nixosModules.default
        (setupConfig { inherit hostName; })
        (toString hostConfig)
      ];
    });

  setupConfig = { hostName }: {
    nix = {
      nixPath = [
        "nixpkgs=${inputs.nixpkgs}"
      ];

      registry = {
        config.flake = outputs;
        nixos.flake = inputs.nixos;
        nixpkgs.flake = inputs.nixpkgs;
      };
    };

    nixpkgs.overlays = [ outputs.overlays.default ];

    networking = { inherit hostName; };

    system = {
      configurationRevision = lib.mkIf (outputs ? rev) outputs.rev;
      stateVersion = outputs.stateVersion;
    };

    home-manager = {
      sharedModules = [
        inputs.neovim.nixosModules.neovim
        outputs.homeModules.default
      ];
    };
  };

in
nixosSystems systemConfigs

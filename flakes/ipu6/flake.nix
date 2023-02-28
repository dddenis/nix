{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    ipu6-drivers.url = "github:intel/ipu6-drivers";
    ipu6-drivers.flake = false;

    ipu6-camera-bins.url = "github:intel/ipu6-camera-bins";
    ipu6-camera-bins.flake = false;

    ipu6-camera-hal.url = "github:intel/ipu6-camera-hal";
    ipu6-camera-hal.flake = false;

    icamerasrc.url = "github:intel/icamerasrc/icamerasrc_slim_api";
    icamerasrc.flake = false;

    ivsc-driver.url = "github:intel/ivsc-driver";
    ivsc-driver.flake = false;

    ivsc-firmware.url = "github:intel/ivsc-firmware";
    ivsc-firmware.flake = false;

    v4l2loopback.url = "git+https://git.launchpad.net/ubuntu/+source/v4l2loopback?ref=ubuntu/devel";
    v4l2loopback.flake = false;

    v4l2-relayd.url = "git+https://gitlab.com/vicamo/v4l2-relayd";
    v4l2-relayd.flake = false;
  };

  outputs = inputs@{ self, ... }:
    ({
      overlays.default = _: prev: {
        inherit (self.packages."${prev.system}")
          ipu6-drivers
          ipu6-camera-bin
          ipu6ep-camera-bin
          ipu6-camera-hal
          ipu6ep-camera-hal
          ipu6-icamerasrc
          ipu6ep-icamerasrc
          ivsc-driver
          ivsc-firmware
          v4l2loopback
          v4l2-relayd;
      };

      nixosModules.default = {
        imports = [ ./module.nix ];
        nixpkgs.overlays = [ self.overlays.default ];
      };
    }
    //
    inputs.flake-utils.lib.eachSystem
      [
        "x86_64-linux"
        "aarch64-linux"
      ]
      (system:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };

          linuxPackages = pkgs.linuxPackages_latest;

        in
        {
          packages = rec {
            ipu6-drivers = pkgs.callPackage ./ipu6-drivers.nix {
              src = inputs.ipu6-drivers;
              kernel = linuxPackages.kernel;
            };

            ipu6-camera-bin = pkgs.callPackage ./ipu6-camera-bins.nix {
              src = inputs.ipu6-camera-bins;
              ipuVersion = "ipu6";
            };

            ipu6ep-camera-bin = pkgs.callPackage ./ipu6-camera-bins.nix {
              src = inputs.ipu6-camera-bins;
              ipuVersion = "ipu6ep";
            };

            ipu6-camera-hal = pkgs.callPackage ./ipu6-camera-hal.nix {
              src = inputs.ipu6-camera-hal;
              ipu6-camera-bin = ipu6-camera-bin;
            };

            ipu6ep-camera-hal = pkgs.callPackage ./ipu6-camera-hal.nix {
              src = inputs.ipu6-camera-hal;
              ipu6-camera-bin = ipu6ep-camera-bin;
            };

            ipu6-icamerasrc = pkgs.callPackage ./icamerasrc.nix {
              src = inputs.icamerasrc;
              ipu6-camera-hal = ipu6-camera-hal;
            };

            ipu6ep-icamerasrc = pkgs.callPackage ./icamerasrc.nix {
              src = inputs.icamerasrc;
              ipu6-camera-hal = ipu6ep-camera-hal;
            };

            ivsc-driver = pkgs.callPackage ./ivsc-driver.nix {
              src = inputs.ivsc-driver;
              kernel = linuxPackages.kernel;
            };

            ivsc-firmware = pkgs.callPackage ./ivsc-firmware.nix {
              src = inputs.ivsc-firmware;
            };

            v4l2loopback = import ./v4l2loopback.nix {
              src = inputs.v4l2loopback;
              v4l2loopback = linuxPackages.v4l2loopback;
            };

            v4l2-relayd = pkgs.callPackage ./v4l2-relayd.nix {
              src = inputs.v4l2-relayd;
            };
          };
        })
    );
}

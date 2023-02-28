{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.ipu6;

  kernel = config.boot.kernelPackages.kernel;

  ipu6-drivers = pkgs.ipu6-drivers.override { inherit kernel; };
  ivsc-driver = pkgs.ivsc-driver.override { inherit kernel; };

  ipuPkg = name: pkgs."${cfg.ipuVersion}-${name}";
  camera-bin = ipuPkg "camera-bin";
  camera-hal = ipuPkg "camera-hal";
  icamerasrc = ipuPkg "icamerasrc";

in
{
  options.hardware.ipu6 = {
    enable = lib.mkEnableOption "IPU6 Drivers & Firmware";

    ipuVersion = lib.mkOption {
      type = lib.types.enum [
        "ipu6"
        "ipu6ep"
      ];
      description = ''
        IPU6 Version:
          - ipu6 (Tiger Lake)
          - ipu6ep (Alder Lake)
      '';
    };

    cameraName = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "MIPI Camera";
      description = ''
        MIPI Camera Name
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.firmware = with pkgs; [
      camera-bin
      ivsc-firmware
    ];

    boot.kernelPatches = [
      {
        name = "IOMMU-passthrough-for-intel-ipu";
        patch = "${ipu6-drivers.src}/patch/IOMMU-passthrough-for-intel-ipu.diff";
      }
      {
        name = "int3472-support-independent-clock-and-LED-gpios-5.17+.patch";
        patch = "${ipu6-drivers.src}/patch/int3472-support-independent-clock-and-LED-gpios-5.17+.patch";
      }
    ];

    boot.extraModulePackages = with pkgs; [
      ipu6-drivers
      v4l2loopback
    ];

    boot.kernelModules = [ "v4l2loopback" ];

    boot.extraModprobeConfig = ''
      options v4l2loopback exclusive_caps=1 card_label="${cfg.cameraName}"
    '';

    systemd.services.v4l2-relayd = {
      environment = {
        CAMERA_CFG_PATH = "${camera-hal}/share/defaults/etc/camera/";
        GST_DEBUG = "2";
        GST_PLUGIN_SYSTEM_PATH_1_0 =
          lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0"
            (with pkgs.gst_all_1; [
              icamerasrc
              gstreamer
              gst-plugins-base
              gst-plugins-good
            ]);
        LD_LIBRARY_PATH = "${camera-bin}/lib";
      };

      script = ''
        DEVICE=$(grep -l -m1 -E "^${cfg.cameraName}$" /sys/devices/virtual/video4linux/*/name | cut -d/ -f6);

        exec ${pkgs.v4l2-relayd}/bin/v4l2-relayd \
          --debug \
          -i "icamerasrc" \
          -o "appsrc name=appsrc caps=video/x-raw,format=NV12,width=1280,height=720,framerate=30/1 ! videoconvert ! video/x-raw,format=YUY2 ! v4l2sink name=v4l2sink device=/dev/$DEVICE"
      '';

      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = "root";
        Group = "root";
      };
    };
  };
}

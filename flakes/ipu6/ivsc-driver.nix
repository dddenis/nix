{ src
, stdenv
, kernel
}:

stdenv.mkDerivation rec {
  pname = "ivsc-driver";
  version = src.rev;
  inherit src;

  hardeningDisable = [ "pic" ];
  nativeBuildInputs = kernel.moduleBuildDependencies;
  enableParallelBuilding = true;

  makeFlags = [
    "KERNELRELEASE=${kernel.modDirVersion}"
    "KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "INSTALL_MOD_PATH=$(out)"
  ];

  installTargets = [
    "modules_install"
  ];
}

{ src
, stdenv
, kernel
, ivsc-driver
}:

stdenv.mkDerivation rec {
  pname = "ipu6-drivers";
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

  postPatch = ''
    cp --no-preserve=mode --recursive --verbose \
      ${ivsc-driver.src}/{drivers,backport-include,include} \
      .
  '';
}

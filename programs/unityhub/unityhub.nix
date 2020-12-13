{ stdenv, fetchurl, appimageTools, gsettings-desktop-schemas, gtk3, jdk }:

let version = "2.3.2";
in appimageTools.wrapType2 rec {
  name = "unityhub";

  extraPkgs = (pkgs:
    with pkgs;
    with xorg; [
      alsaLib
      cairo
      clang
      corefonts
      cups
      dbus
      dbus-glib
      expat
      fontconfig
      freetype
      gdk_pixbuf
      glib
      gnome2.GConf
      gtk2
      gtk3
      jdk
      libGL
      libGLU
      libcap
      libdbusmenu
      libdbusmenu-gtk2
      libpng12
      libpqxx
      libpulseaudio
      libsecret
      libselinux
      libxml2
      llvmPackages.bintools
      lsb-release
      ncurses5
      nodejs
      nspr
      nss
      openssl
      pango
      pciutils
      tbb
      udev
      zlib

      libICE
      libSM
      libX11
      libXcomposite
      libXcursor
      libXdamage
      libXext
      libXfixes
      libXi
      libXrandr
      libXrender
      libXtst
      libxcb
    ]);

  profile = ''
    export XDG_DATA_DIRS=${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}:$XDG_DATA_DIRS
  '';

  src = fetchurl {
    # mirror of https://public-cdn.cloud.unity3d.com/hub/prod/UnityHub.AppImage
    url = "https://archive.org/download/unity-hub-${version}/UnityHub.AppImage";
    sha256 = "07nfyfp9apshqarc6pgshsczila6x4943hiyyizc55kp85aw0imn";
  };

  meta = with stdenv.lib; {
    homepage = "https://unity3d.com/";
    description = "Game development tool";
    longDescription = ''
      Popular development platform for creating 2D and 3D multiplatform games
      and interactive experiences.
    '';
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ tesq0 ];
  };
}

{ config, lib, options, pkgs, ... }:

{
  imports = lib.findFilesRec {
    path = ./.;
    regex = "^.*\\.nix$";
    excludeDirs = [ ./. ];
  };

  options = {
    hm = lib.mkOption {
      type = options.home-manager.users.type.functor.wrapped;
      default = { };
    };

    user = lib.mkOption { type = options.users.users.type.functor.wrapped; };
  };
}

{ config, pkgs, lib, ... }:

let
  userConfigs =
    pkgs.lib.user.filterConfigs (userConfig: userConfig.services.kmonad.enable)
    config;

  mkNixosUserConfigs = value:
    builtins.listToAttrs
    (map (userConfig: lib.nameValuePair userConfig.home.username value)
      userConfigs);

in {
  config = lib.mkIf (!(pkgs.lib.isEmpty userConfigs)) {
    users = {
      groups.uinput = { };

      users = mkNixosUserConfigs { extraGroups = [ "input" "uinput" ]; };
    };

    services.udev.extraRules = ''
      # KMonad user access to /dev/uinput
      KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
    '';
  };
}

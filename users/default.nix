{ lib, inputs, outputs }:

let
  userConfigs = builtins.listToAttrs
    (map (path: lib.nameValuePair (lib.fs.baseDirOf path) path)
      (lib.fs.findFilesRec { path = ./.; }));

in builtins.mapAttrs (_: userConfig: {
  imports = [ outputs.homeModule userConfig ];

  home.stateVersion = outputs.stateVersion;
}) userConfigs
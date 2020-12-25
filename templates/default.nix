{ lib }:

let
  templates =
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.);

in builtins.mapAttrs (name: _: {
  description = name;
  path = ./. + "/${name}";
}) templates

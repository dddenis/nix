{ config, lib, pkgs, inputs, ... }:

let cfg = config.ddd.programs.omp;

in
{
  imports = [ inputs.omp.homeManagerModules.default ];

  options.ddd.programs.omp.enable = lib.mkEnableOption "oh-my-pi";

  config = lib.mkIf cfg.enable {
    programs.omp.enable = true;

    home.file.".local/bin/omp-unwrapped" = {
      # Exec the real basename so Herdr detects omp rather than omp-unwrapped.
      source = pkgs.writeShellScript "omp-unwrapped" ''
        exec "${inputs.omp.packages.${pkgs.stdenv.hostPlatform.system}.omp}/bin/omp" "$@"
      '';
      force = true;
    };

    home.file.".omp/agent/config.yml" = {
      source = config.lib.file.mkOutOfStoreSymlink
        "${config.home.configPath}/modules/home-manager/programs/omp/config.yml";
      force = true;
    };

    home.file.".omp/agent/extensions" = {
      source = config.lib.file.mkOutOfStoreSymlink
        "${config.home.configPath}/modules/home-manager/programs/omp/extensions";
      force = true;
    };

    home.file.".omp/agent/themes" = {
      source = config.lib.file.mkOutOfStoreSymlink
        "${config.home.configPath}/modules/home-manager/programs/omp/themes";
      force = true;
    };
  };
}

{ config, lib, ... }:

let cfg = config.programs.git;

in {
  options.programs.git.enable' = lib.mkEnableOption "git";

  config = lib.mkIf cfg.enable' {
    programs.git = {
      enable = true;
      userName = "Denis Goncharenko";
      userEmail = lib.mkDefault "dddenjer@gmail.com";
      ignores = [ ".log/" ".vim/" ".ignore" ];
      extraConfig = {
        pull.rebase = true;
      };
    };
  };
}

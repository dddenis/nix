{ config, lib, pkgs, ... }:

let
  isEnabled =
    lib.user.anyConfig (userConfig: userConfig.programs.tmux.enable') config;

  tmux-256color = builtins.fetchurl {
    url =
      "https://gist.githubusercontent.com/nicm/ea9cf3c93f22e0246ec858122d9abea1/raw/37ae29fc86e88b48dbc8a674478ad3e7a009f357/tmux-256color";
    sha256 = "18znnmsl53nhv0gxacvd6435599afsz2ig0wyylbj04rchqrl9cg";
  };

in lib.mkIf isEnabled {
  environment.extraInit = ''
    tic -xe tmux-256color ${tmux-256color}
  '';
}

{ config, lib, pkgs, ... }:

let cfg = config.programs.vim;

in lib.mkIf cfg.enable' {
  xdg.mimeApps.defaultApplications = { "text/plain" = "vim.desktop"; };
}

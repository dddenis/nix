{ config, lib, pkgs, ... }:

let cfg = config.programs.google-chrome;

in {
  options.programs.google-chrome.enable' = lib.mkEnableOption "google-chrome";

  config = lib.mkIf cfg.enable' {
    home.packages = [ pkgs.google-chrome ];

    xdg.mimeApps = {
      enable = true;

      defaultApplications = {
        "application/pdf" = "google-chrome.desktop";
        "text/html" = "google-chrome.desktop";
        "x-scheme-handler/about" = "google-chrome.desktop";
        "x-scheme-handler/http" = "google-chrome.desktop";
        "x-scheme-handler/https" = "google-chrome.desktop";
        "x-scheme-handler/unknown" = "google-chrome.desktop";
        "x-scheme-handler/webcal" = "google-chrome.desktop";
      };
    };
  };
}

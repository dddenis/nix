{ config, lib, pkgs, ... }:

let
  cfg = config.programs.vscode;

  font = "Iosevka DDD Term";

in {
  options.programs.vscode.enable' = lib.mkEnableOption "vscode";

  config = lib.mkIf cfg.enable' {
    fonts.fonts = with pkgs; [ iosevka-ddd-term-font ];

    programs.vscode = lib.mkMerge [{
      enable = true;

      extensions = with pkgs.vscode-extensions; [ vscodevim.vim ];

      userSettings = {
        "breadcrumbs.enabled" = true;
        "diffEditor.ignoreTrimWhitespace" = true;
        "editor.acceptSuggestionOnCommitCharacter" = false;
        "editor.acceptSuggestionOnEnter" = "off";
        "editor.codeActionsOnSave" = { "source.organizeImports" = true; };
        "editor.detectIndentation" = false;
        "editor.dragAndDrop" = false;
        "editor.fontFamily" = font;
        "editor.fontLigatures" = true;
        "editor.fontSize" = 14;
        "editor.formatOnSave" = true;
        "editor.lineNumbers" = "relative";
        "editor.minimap.enabled" = false;
        "editor.rulers" = [ 100 ];
        "editor.snippetSuggestions" = "none";
        "editor.tabSize" = 2;
        "emmet.showExpandedAbbreviation" = "inMarkupAndStylesheetFilesOnly";
        "explorer.confirmDragAndDrop" = false;
        "files.insertFinalNewline" = true;
        "files.trimFinalNewlines" = true;
        "files.trimTrailingWhitespace" = true;
        "git.confirmSync" = false;
        "gitlens.codeLens.enabled" = false;
        "gitlens.hovers.enabled" = false;
        "javascript.updateImportsOnFileMove.enabled" = "always";
        "prettier.printWidth" = 100;
        "prettier.singleQuote" = true;
        "prettier.trailingComma" = "all";
        "razor.disabled" = true;
        "terminal.integrated.fontFamily" = font;
        "typescript.preferences.importModuleSpecifier" = "relative";
        "typescript.updateImportsOnFileMove.enabled" = "always";
        "vim.easymotion" = true;
        "vim.easymotionMarkerFontFamily" = font;
        "vim.leader" = "<Space>";
        "vim.normalModeKeyBindingsNonRecursive" = [
          {
            "before" = [ "<C-h>" ];
            "commands" = [ "workbench.action.navigateLeft" ];
          }
          {
            "before" = [ "<C-k>" ];
            "commands" = [ "workbench.action.navigateUp" ];
          }
          {
            "before" = [ "<C-j>" ];
            "commands" = [ "workbench.action.navigateDown" ];
          }
          {
            "before" = [ "<C-l>" ];
            "commands" = [ "workbench.action.navigateRight" ];
          }
          {
            "before" = [ "leader" "f" "s" ];
            "commands" = [ "workbench.action.files.save" ];
          }
          {
            "before" = [ "K" ];
            "after" = [ "g" "h" ];
          }
          {
            "before" = [ "leader" "c" "r" ];
            "commands" = [ "editor.action.rename" ];
          }
          {
            "before" = [ "leader" "g" ];
            "after" = [ "leader" "leader" "leader" "b" "d" "w" ];
          }
        ];
        "vim.sneak" = true;
        "vim.useSystemClipboard" = true;
        "window.titleBarStyle" = "custom";
        "workbench.colorTheme" = "Gruvbox Dark Medium";
        "workbench.editor.enablePreview" = false;
        "workbench.startupEditor" = "newUntitledFile";
        "[html]" = { "editor.defaultFormatter" = "esbenp.prettier-vscode"; };
        "[javascript]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };
        "[json]" = { "editor.defaultFormatter" = "esbenp.prettier-vscode"; };
        "[markdown]" = {
          "files.trimTrailingWhitespace" = false;
          "editor.wordWrap" = "on";
          "editor.quickSuggestions" = false;
        };
        "[typescriptreact]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };
      };
    }];

    xdg.configFile."Code/User/keybindings.json".text = builtins.toJSON [
      {
        "key" = "ctrl+j";
        "command" = "workbench.action.quickOpenSelectNext";
        "when" = "inQuickOpen";
      }
      {
        "key" = "ctrl+k";
        "command" = "workbench.action.quickOpenSelectPrevious";
        "when" = "inQuickOpen";
      }
      {
        "key" = "ctrl+j";
        "command" = "selectNextSuggestion";
        "when" =
          "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus";
      }
      {
        "key" = "ctrl+k";
        "command" = "selectPrevSuggestion";
        "when" =
          "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus";
      }
      {
        "key" = "ctrl+l";
        "command" = "acceptSelectedSuggestion";
        "when" = "suggestWidgetVisible && textInputFocus";
      }
      {
        "key" = "ctrl+l";
        "command" = "workbench.action.navigateRight";
        "when" = "listFocus && !inputFocus";
      }
      {
        "key" = "] e";
        "command" = "editor.action.marker.next";
        "when" = "editorFocus && vim.mode == 'Normal'";
      }
      {
        "key" = "alt+f8";
        "command" = "-editor.action.marker.next";
        "when" = "editorFocus";
      }
      {
        "key" = "[ e";
        "command" = "editor.action.marker.prev";
        "when" = "editorFocus && vim.mode == 'Normal'";
      }
      {
        "key" = "shift+alt+f8";
        "command" = "-editor.action.marker.prev";
        "when" = "editorFocus";
      }
    ];
  };
}

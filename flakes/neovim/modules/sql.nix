{ pkgs, ... }:

let
  sqlFormatterConfig = pkgs.writeText "sql-formatter-config" (builtins.toJSON {
    language = "postgresql";
    keywordCase = "upper";
    expressionWidth = 100;
  });

in
{
  config.programs.ddd.neovim.lsp.null-ls.sources = [
    ''
      require'null-ls'.builtins.formatting.sql_formatter.with({
        extra_args = { '--config', '${sqlFormatterConfig}' },
      })
    ''
  ];

  config.programs.ddd.neovim.packages = with pkgs; [
    nodePackages.sql-formatter
  ];
}


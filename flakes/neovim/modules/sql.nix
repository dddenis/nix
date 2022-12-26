{ neovimPkgs, ... }:

let
  sqlFormatterConfig = neovimPkgs.writeText "sql-formatter-config"
    (builtins.toJSON {
      language = "postgresql";
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

  config.programs.ddd.neovim.packages = with neovimPkgs; [
    nodePackages.sql-formatter
  ];
}


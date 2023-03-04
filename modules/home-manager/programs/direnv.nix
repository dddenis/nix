{ config, lib, ... }:

let cfg = config.ddd.programs.direnv;

in
{
  options.ddd.programs.direnv.enable = lib.mkEnableOption "direnv";

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;

      stdlib = ''
        export_alias() {
          local name=$1
          shift
          local alias_dir=$PWD/.direnv/aliases
          local target="$alias_dir/$name"
          mkdir -p "$alias_dir"
          if ! [[ ":$PATH:" == *":$alias_dir:"* ]]; then
            PATH_add "$alias_dir"
          fi

          echo "#!/usr/bin/env -S bash -e" > "$target"
          echo "$@" >> "$target"
          chmod +x "$target"
        }
      '';
    };
  };
}

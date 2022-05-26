{ config, lib, ... }:

let cfg = config.programs.direnv;

in {
  options.programs.direnv.enable' = lib.mkEnableOption "direnv";

  config = lib.mkIf cfg.enable' {
    nix.extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';

    hm.programs.direnv = {
      enable = true;
      enableZshIntegration = true;

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

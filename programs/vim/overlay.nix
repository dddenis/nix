self: super:

let
  inherit (super.vimUtils) buildVimPluginFrom2Nix;

in {
  # vimPlugins = super.vimPlugins // {
  #   coc-nvim = buildVimPluginFrom2Nix {
  #     pname = "coc-nvim";
  #     version = "2020-10-29";
  #     src = super.fetchFromGitHub {
  #       owner = "neoclide";
  #       repo = "coc.nvim";
  #       rev = "a9410fe8b0038d1700b43df36a4745149e92feac";
  #       sha256 = "1j1h6imxjnnngijf7prraahmwrqvygcc0awm6zs9j4cm2k9c29fp";
  #     };
  #     meta.homepage = "https://github.com/neoclide/coc.nvim/";
  #   };
  # };
}

nixpkgsLib:

nixpkgsLib.extend (_: prev: import ./. { lib = prev; })

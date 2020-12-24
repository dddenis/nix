nixpkgsLib:

nixpkgsLib.extend (self: super: import ./. { lib = super; })

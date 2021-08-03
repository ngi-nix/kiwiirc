{ pkgs ? import <nixpkgs> { inherit system; }, system ? builtins.currentSystem
}:
let 
  nodePackages = import ./default.nix { inherit pkgs system; };
  nodeDependencies = (pkgs.callPackage ./default.nix {}).shell.nodeDependencies;
in nodePackages // {
  package = nodePackages.package.override {
    buildInputs = [
      pkgs.makeWrapper
      pkgs.nodePackages.node-gyp-build
      pkgs.libtool
      pkgs.autoconf
      pkgs.automake
      pkgs.nodejs
    ];
    buildPhase = ''
      ln -s ${nodeDependencies}/lib/node_modules ./node_modules
      export PATH="${nodeDependencies}/bin:$PATH"
  
      # Build the distribution bundle in "dist"
      webpack
      cp -r dist $out/
    '';
  };
}

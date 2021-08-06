{
  description = "🥝 Next generation of the Kiwi IRC web client";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-21.05";
  inputs.yarn2nix.url = "github:input-output-hk/yarn2nix";

  outputs = { self, nixpkgs, yarn2nix }:
    let
      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay yarn2nix.overlay ]; });
    in {
      overlay = final: prev: {
        kiwiirc = final.mkYarnPackage rec {
          src = ./.;
          pname = "kiwiirc";
          distPhase = "true";
          buildPhase = ''
            yarn --offline run build
          '';
          preInstall = ''
            mkdir -p $out/www/${pname}
            cp -r ./deps/${pname}/dist/* $out/www/${pname}
          '';
          postFixup = ''
            rm -rf $out/tarballs $out/libexec $out/bin
          '';
        };
      };

      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) kiwiirc;
        });

      defaultPackage = forAllSystems (system: self.packages.${system}.kiwiirc);

      hydraJobs.kiwiirc = self.defaultPackage;
    };
}

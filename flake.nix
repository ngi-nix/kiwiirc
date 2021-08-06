{
  description = "🥝 Next generation of the Kiwi IRC web client";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-21.05";
  inputs.webircgateway = {
    url = "github:kiwiirc/webircgateway";
    flake = false;
  };

  outputs = { self, nixpkgs, webircgateway }:
    let
      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });
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
        webircgateway = final.buildGoModule rec {
          src = webircgateway;
          pname = "webircgateway";
          vendorSha256 = "1a3x6cv18f0n01f4ac1kprzmby8dphygnwsdl98pmzs3gqqnh284";
        };
      };

      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) kiwiirc;
          inherit (nixpkgsFor.${system}) webircgateway;
        });

      defaultPackage = forAllSystems (system: self.packages.${system}.kiwiirc);

      hydraJobs.kiwiirc = self.defaultPackage;
    };
}

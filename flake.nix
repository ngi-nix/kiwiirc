{
  description = "package description goes here";

  inputs.utils.url = "github:kreisys/flake-utils";
  inputs.yarn2nix.url = "github:input-output-hk/yarn2nix";

  outputs = { self, nixpkgs, yarn2nix, utils }:
    utils.lib.simpleFlake
      {
        inherit nixpkgs;
        systems = [ "x86_64-linux" "x86_64-darwin" ];
        preOverlays = [ yarn2nix ];
        overlay = final: prev: {
          package-name = final.callPackage ./package.nix { };
        };

        packages = { package-name }: {
          inherit package-name;
          defaultPackage = package-name;
        };

        hydraJobs = { package-name }@jobs: jobs;
      };
}

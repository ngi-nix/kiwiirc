{
  nixConfig.bash-prompt = "[nix-develop:]";

  description = "🥝 Next generation of the Kiwi IRC web client";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-21.05";
  inputs.webircgateway = {
    url = "github:kiwiirc/webircgateway";
    flake = false;
  };
  inputs.kiwiirc-desktop = {
    url = "github:kiwiirc/kiwiirc-desktop";
    flake = false;
  };

  outputs = { self, nixpkgs, webircgateway, kiwiirc-desktop }:
    let
      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });
    in {
      overlay = final: prev:
        let
          kiwiirc = final.mkYarnPackage rec {
            src = ./.;
            pname = "kiwiirc";
            distPhase = "true";
            buildPhase = ''
              yarn --offline run build
            '';
            preInstall = ''
              mkdir -p $out/www/${pname}
              cp -r ./deps/${pname}/dist/* $out/www
            '';
            postFixup = ''
              rm -rf $out/tarballs $out/libexec $out/bin
            '';
          };
        in {
          inherit kiwiirc;
          kiwiirc-desktop = let executableName = "kiwiirc-desktop";
          in final.mkYarnPackage {
            name = "kiwiirc-desktop";
            src = kiwiirc-desktop;
            patches = ((final.writeText "remove-dev-mode.patch" ''
              diff --git a/src/index.js b/src/index.js
              index 1ac9c27..d5cbb79 100644
              --- a/src/index.js
              +++ b/src/index.js
              @@ -141,9 +141,4 @@ app.on('activate', async () => {
                           app.quit();
                       });
                   }
              -
              -    if (process.defaultApp) {
              -        // Running in dev mode
              -        mainWindow.webContents.openDevTools();
              -    }
               })();
            ''));
            nativeBuildInputs = [ final.makeWrapper ];
            installPhase = ''
              # resources
              mkdir -p "$out/share/kiwiirc"
              cp -r './deps/kiwiirc-desktop' "$out/share/kiwiirc/electron"

              rm "$out/share/kiwiirc/electron/node_modules"
              cp -r './node_modules' "$out/share/kiwiirc/electron"

              rm -r "$out/share/kiwiirc/electron/kiwiirc"
              mkdir -p  "$out/share/kiwiirc/electron/kiwiirc"
              ln -s '${kiwiirc}/www' "$out/share/kiwiirc/electron/kiwiirc/dist"

              # executable wrapper
              makeWrapper '${final.electron}/bin/electron' "$out/bin/${executableName}" \
                --add-flags "$out/share/kiwiirc/electron"
            '';

            distPhase = ''
              true
            '';
          };
        webircgateway = final.buildGoModule rec {
          src = webircgateway;
          name = "webircgateway";
          pname = "webircgateway";
          vendorSha256 = "sha256-CzA99tijUdmi46x9hV8bKR9uVK1HivG/QpciXwpstlU=";
          subPackages = [ "." ];
          runVend = true;
        };
      };

      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) kiwiirc kiwiirc-desktop webircgateway;
        });

      defaultPackage = forAllSystems (system: self.packages.${system}.kiwiirc);

      nixosModules.kiwiirc =
        { pkgs, lib, config, ... }:
          with lib;
        {
          options.services.kiwiirc = {
            enable = mkEnableOption "Serve the KiwiIRC webpage";
          };
          config = mkIf config.services.kiwiirc.enable {
            nixpkgs.overlays = [ self.overlay ];
            systemd.services.kiwiirc = {
              description = "The KiwiIRC Service";
              wantedBy = [ "multi-user.target" ];
              after = [ "networking.target" ];
              serviceConfig = {
                DynamicUser = true;
                ExecStart = "${pkgs.python3}/bin/python -m http.server 8000 -d ${pkgs.kiwiirc}/www";
                PrivateTmp = true;
                Restart = "always";
              };
            };
          };
        };

      checks = forAllSystems
        (system:
          with nixpkgsFor.${system};
          lib.optionalAttrs stdenv.isLinux {
            # A VM test of the NixOS module.
            vmTest =
              with import (nixpkgs + "/nixos/lib/testing-python.nix") {
                inherit system;
              };

              makeTest {
                nodes = {
                  client = { config, pkgs, ... }: {
                    environment.systemPackages = [ pkgs.curl ];
                  };
                  kiwiirc = { config, pkgs, ... }: {
                    imports = [ self.nixosModules.kiwiirc ];
                    services.kiwiirc.enable = true;
                    networking.firewall.enable = false;
                  };
                };

                testScript =
                  ''
                    start_all()
                    client.wait_for_unit("multi-user.target")
                    kiwiirc.wait_for_unit("kiwiirc.service")
                    kiwiirc.wait_for_open_port("8000")
                    client.succeed("curl -sSf http:/kiwiirc:8000/static/config.json")
                  '';
              };
          }
        );

      hydraJobs.kiwiirc = self.defaultPackage;
    };
}

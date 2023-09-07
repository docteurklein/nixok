{
  inputs.kubenix = {
    url = "github:hall/kubenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nix2container = {
    url = "github:nlewo/nix2container";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nixng = {
    url = "github:nix-community/NixNG";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.terranix = {
    url = "github:terranix/terranix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.phpComposerBuilder = {
    url = "github:loophp/nix-php-composer-builder";
  };

  outputs = inputs@{self, nixpkgs, terranix, phpComposerBuilder, nixng, kubenix, nix2container, ... }:
    let
      systems = [ "x86_64-linux"];
    in {
    nixngConfigurations = nixpkgs.lib.genAttrs systems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.extend phpComposerBuilder.overlays.default;
      in {
      phpweb = nixng.nglib.makeSystem {
        inherit system nixpkgs;
        name = "phpweb";
        config = ({ config, ... }: {
          package = (pkgs.api.buildComposerProject {
            src = ./php;
            php = pkgs.api.buildPhpFromComposer { src = ./php; };
            pname = "test";
            version = "1.0.0-dev";
            vendorHash = "sha256-ZdxRo0tzoKXPXrgA4Q9Kc5JSEEoqcTV/uvMMMD1z7NI=";
            meta.mainProgram = "test";
          });
          imports = [
            ./nixng/phpweb.nix
          ];
        });
      };
    });
    packages = nixpkgs.lib.genAttrs systems (system:
      let
        nix2c = nix2container.packages.${system}.nix2container;
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        phpweb-image = nix2c.buildImage {
          name = "docteurklein/phpweb";
          config = {
            StopSignal = "SIGWINCH";
            Entrypoint = [ "${self.nixngConfigurations.${system}.phpweb.config.system.build.toplevel}/init" ];
            ExposedPorts = {
              "80/tcp" = {};
            };
          };
          copyToRoot = [
            (pkgs.buildEnv {
              name = "root";
              paths = with pkgs; [
                bashInteractive
                coreutils
                procps
              ];
              pathsToLink = [ "/bin" ];
            })
          ];
          # layers = [
          #   (nix2c.buildLayer {
          #     deps = [pkgs.bashInteractive];
          #   })
          # ];
          maxLayers = 125;
        };
        kubeManifest = (kubenix.evalModules.${system} {
          module = { lib, kubenix, config, ... }: {
            imports = [
              kubenix.modules.docker
              ./kubenix/modules/phpweb.nix
            ];
            docker = {
              registry.url = "docker.io";
              images.phpweb.image = self.packages.${system}.phpweb-image;
            };

            # kubenix.project = "test1";
            # kubernetes.version = "1.27";
          };
        }).config.kubernetes.result;

        terranixConfig = terranix.lib.terranixConfiguration {
          inherit system;
          modules = [
            ./terranix/config.nix
          ];
        };
      }
    );
    apps = nixpkgs.lib.genAttrs systems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        terraform = pkgs.terraform;
      in {
        tf = {
          type = "app";
          program = toString (pkgs.writers.writeBash "apply" ''
            cp -vf ${self.packages.${system}.terranixConfig} config.tf.json
            ${terraform}/bin/terraform init
            ${terraform}/bin/terraform $1
          '');
        };
      }
    );
    devShells = nixpkgs.lib.genAttrs systems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [ k3s terraform kubectl skopeo phpactor ];
        };
      }
    );
  };
}
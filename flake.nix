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
    url = "github:docteurklein/NixNG/php-ini-fix";
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
      systems = [ "x86_64-linux" ];
      tfoutput = builtins.fromJSON (builtins.readFile ./tfoutput); # @TODO Import-From-Derivation?
    in {
    stack = nixpkgs.lib.genAttrs systems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in (pkgs.lib.evalModules {
        modules = [
          ./stack/modules/service.nix
          ({config, ...}: {
            services.a = {};
            services.b = {};
          })
        ];
      }).config
    );
    nixosModules = nixpkgs.lib.genAttrs systems (system: {
      phpweb = ({config, modulesPath, lib, ...}: {
        imports= [
         "${modulesPath}/profiles/minimal.nix"
         ./nixos/phpweb.nix
        ];
        boot.isContainer = true;
        environment.noXlibs = lib.mkForce true;
        documentation.enable = lib.mkForce false;
        documentation.nixos.enable = lib.mkForce false;
        networking.firewall.enable = false;
        security.audit.enable = false;
        programs.command-not-found.enable = lib.mkForce false; 
        services.udisks2.enable = lib.mkForce false;
        services.nscd.enable = lib.mkForce false;
        system.nssModules = lib.mkForce [];
      });
    });
    nixosConfigurations = nixpkgs.lib.genAttrs systems (system: {
      phpweb = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
            self.nixosModules.${system}.phpweb
        ];
      };
    });
    nixngConfigurations = nixpkgs.lib.genAttrs systems (system: {
      phpweb = nixng.nglib.makeSystem rec {
        inherit system nixpkgs;
        name = "phpweb";
        config = ({ config, lib, ... }: {
          inherit name;
          package = self.packages.${system}.phpweb-composer;

          imports = [
            ./nixng/phpweb.nix
          ];
        });
      };
    });
    packages = nixpkgs.lib.genAttrs systems (system:
      let
        nix2c = nix2container.packages.${system}.nix2container;
        pkgs = nixpkgs.legacyPackages.${system}.extend phpComposerBuilder.overlays.default;
      in {
        phpweb-composer = pkgs.api.buildComposerProject rec {
          src = ./php;
          php = pkgs.api.buildPhpFromComposer { inherit src; };
          pname = "phpweb";
          version = "1.0.0-dev";
          vendorHash = "sha256-ZdxRo0tzoKXPXrgA4Q9Kc5JSEEoqcTV/uvMMMD1z7NI=";
          # meta.mainProgram = "test";
        };
        phpweb-image = nix2c.buildImage {
          name = "docteurklein/phpweb";
          config = {
            StopSignal = "SIGWINCH"; # @TODO: use nixng sigell?
            # Entrypoint = [ "${self.nixosConfigurations.${system}.phpweb.config.services.phpfpm.pools.phpweb.phpPackage}/bin/php-fpm" ];
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

        kube-manifest = self.kubenix.${system}.kube-manifest.result;

        terraform-config = (pkgs.formats.json { }).generate "config.tf.json" self.terranix.${system}.ast.config;
      }
    );
    terranix = nixpkgs.lib.genAttrs systems (system: {
      ast = terranix.lib.terranixConfigurationAst {
        inherit system;
        modules = [
          ./terranix/config.nix
        ];
      };
    });
    kubenix = nixpkgs.lib.genAttrs systems (system: {
      kube-manifest = (kubenix.evalModules.${system} {
        specialArgs = {
          tfAst = self.terranix.${system}.ast.config;
          stack = self.stack.${system};
        };

        module = { lib, kubenix, config, ... }: {
          imports = [
            kubenix.modules.docker
            ./kubenix/modules/tfoutput.nix
            ./kubenix/modules/mkDeployment.nix
          ];

          namespace = tfoutput.test.value;
          services = self.stack.${system}.services;

          docker = {
            registry.url = "docker.io";
            images.phpweb.image = self.packages.${system}.phpweb-image;
            images.phpweb2.image = self.packages.${system}.phpweb-image;
            images.a.image = self.packages.${system}.phpweb-image;
            images.b.image = self.packages.${system}.phpweb-image;
            images.c.image = self.packages.${system}.phpweb-image;
          };

          # kubenix.project = "test1";
          # kubernetes.version = "1.27";
        };
      }).config.kubernetes;
    });
    apps = nixpkgs.lib.genAttrs systems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        terraform = {
          type = "app";
          program = toString (pkgs.writers.writeBash "terraform" ''
            set -exuo pipefail
            cp -vf ${self.packages.${system}.terraform-config} config.tf.json
            ${pkgs.terraform}/bin/terraform init
            ${pkgs.terraform}/bin/terraform "$@"
            ${pkgs.terraform}/bin/terraform output -json > ./tfoutput
          '');
        };
      }
    );
    devShells = nixpkgs.lib.genAttrs systems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [ k3s terraform kubectl phpactor ];
        };
      }
    );
  };
}

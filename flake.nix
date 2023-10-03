{
  inputs.kubenix = {
    url = "github:hall/kubenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  # inputs.nix2container = {
  #   url = "github:nlewo/nix2container";
  #   inputs.nixpkgs.follows = "nixpkgs";
  # };
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
  inputs.nix-snapshotter = {
    url = "github:pdtpartners/nix-snapshotter";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{self, nixpkgs, terranix, phpComposerBuilder, nixng, kubenix, nix-snapshotter, ... }:
    let
      systems = [ "x86_64-linux" ];
      tfoutput = builtins.fromJSON (builtins.readFile ./tfoutput.json); # @TODO Import-From-Derivation?
    in {
    stack = nixpkgs.lib.genAttrs systems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in (pkgs.lib.evalModules {
        specialArgs = {
          inherit tfoutput;
          self = self.packages.${system};
        };
        modules = [
          ./stack/modules/services.nix
          ./stack/modules/workers.nix
        ];
      }).config
    );
    nixosModules = nixpkgs.lib.genAttrs systems (system: {
      phpweb = ({config, modulesPath, lib, ...}: {
        imports= [
         "${modulesPath}/profiles/minimal.nix"
         ./nixos/phpweb.nix
        ];
        package = self.packages.${system}.phpweb-composer;

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
        pkgs = (nixpkgs.legacyPackages.${system}
          .extend phpComposerBuilder.overlays.default)
          .extend nix-snapshotter.overlays.default;
          # .extend (final: prev: {
          #   nix2c = nix2container.packages.${system}.nix2container;
          # });
      in {
        phpweb-composer = pkgs.api.buildComposerProject rec {
          pname = "phpweb";
          version = "1.0.1-dev";
          vendorHash = "sha256-ML9PQKi3XGEEHBRHAan7v72NL84uVZVDGEbACIURUCQ=";
          src = ./php;
          php = pkgs.api.buildPhpFromComposer {
            inherit src;
          };
          postBuild = ''
            mkdir -p $out/etc
            touch $out/etc/php.ini
          '';
        };
        phpweb-image = pkgs.nix-snapshotter.buildImage {
          name = "docteurklein/phpweb";
          resolvedByNix = true;
          config = {
            # StopSignal = "SIGWINCH"; # @TODO: use nixng sigell?
            # Entrypoint = [ "${self.nixosConfigurations.${system}.phpweb.config.services.phpfpm.pools.main.phpPackage}/bin/php-fpm" ];
            # Entrypoint = [ "${self.nixosConfigurations.${system}.phpweb.config.system.build.toplevel}/init" ];
            Entrypoint = [ "/bin/sh" ];

            ExposedPorts = {
              "80/tcp" = {};
              "9000/tcp" = {};
            };
          };
          copyToRoot = pkgs.buildEnv {
            name = "root";
            paths = with pkgs; [
              bashInteractive
              coreutils
              procps
              self.nixosConfigurations.${system}.phpweb.config.system.build.toplevel
              # self.packages.${system}.phpweb-composer
            ];
            pathsToLink = [ "/bin" ];
          };
          # layers = [
          #   (pkgs.nix2c.buildLayer {
          #     deps = [pkgs.bashInteractive];
          #   })
          # ];
          # maxLayers = 125;
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
          ({config, ...}: {
            workers = self.stack.${system}.workers;
          })
        ];
      };
    });
    kubenix = nixpkgs.lib.genAttrs systems (system: {
      kube-manifest = (kubenix.evalModules.${system} {
        specialArgs = {
          tfAst = self.terranix.${system}.ast.config;
        };

        module = { lib, kubenix, config, pkgs, ... }: {
          imports = [
            # kubenix.modules.docker
            ./kubenix/modules/tfoutput.nix
            ./kubenix/modules/mkDeployment.nix
          ];

          kubernetes.resources.deployments.s1.spec.template.spec = {
            # containers."s1-nginx" = {
            #   command = lib.strings.splitString " " self.nixosConfigurations.${system}.phpweb.config.systemd.services.nginx.serviceConfig.ExecStart;
            #   # args = [ "-c" self.nixosConfigurations.${system}.phpweb.config.systemd.services.nginx.serviceConfig.ExecStart ];
            # };
            containers."s1-fpm" = {
              # command = ["/bin/sh"];
              command = lib.strings.splitString " " self.nixosConfigurations.${system}.phpweb.config.systemd.services.phpfpm-main.serviceConfig.ExecStart;
              # args = [ "-c" "sleep 1000" ]; # self.nixosConfigurations.${system}.phpweb.config.systemd.services.phpfpm-main.serviceConfig.ExecStart ];
              # volumeMounts = [
              #   {
              #     name = "src";
              #     mountPath = "/nix/store/jlkbg3wc34hw9wb27jy1vb0xqv8ann88-phpweb-1.0.1-dev/share/php/phpweb";
              #   }
              # ];
            };
            # volumes = [
            #   {
            #     name = "src";
            #     hostPath = {
            #       path = "/home/florian/work/docteurklein/kubenix-test/php";
            #       type = "Directory";
            #     };
            #   }
            # ];
          };

          # namespace = tfoutput.prefix.value;
          services = self.stack.${system}.services;
          # workers = self.stack.${system}.workers;

          # docker = {
          #   registry.url = "docker.io";
          #   images.s1.image = self.packages.${system}.phpweb-image;
          #   images.w1.image = self.packages.${system}.phpweb-image;
          # };

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
            ${pkgs.terraform}/bin/terraform output -json > ./tfoutput.json
          '');
        };
      }
    );
    devShells = nixpkgs.lib.genAttrs systems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [ tmux helix nil k3s terraform kubectl phpactor ];
        };
      }
    );
  };
}

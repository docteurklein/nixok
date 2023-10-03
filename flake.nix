{
  # inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
  inputs.kubenix = {
    url = "github:hall/kubenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nix2container = {
    url = "github:nlewo/nix2container";
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

  outputs = inputs@{self, nixpkgs, terranix, phpComposerBuilder, kubenix, nix-snapshotter, nix2container, ... }:
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

        system.stateVersion = "23.05";
        boot.isContainer = true;
        boot.specialFileSystems = lib.mkForce {};
        environment.noXlibs = lib.mkForce true;
        documentation.enable = lib.mkForce false;
        documentation.nixos.enable = lib.mkForce false;
        networking.firewall.enable = false;
        networking.hostName = "";
        security.audit.enable = false;
        programs.command-not-found.enable = lib.mkForce false; 
        services.udisks2.enable = lib.mkForce false;
        services.nscd.enable = lib.mkForce false;
        services.journald.console = "/dev/console";
        systemd.services.systemd-logind.enable = false;
        systemd.services.console-getty.enable = false;
        systemd.sockets.nix-daemon.enable = lib.mkDefault false;
        systemd.services.nix-daemon.enable = lib.mkDefault false;
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
    # nixngConfigurations = nixpkgs.lib.genAttrs systems (system: {
    #   phpweb = nixng.nglib.makeSystem rec {
    #     inherit system nixpkgs;
    #     name = "phpweb";
    #     config = ({ config, lib, ... }: {
    #       inherit name;
    #       package = self.packages.${system}.phpweb-composer;

    #       imports = [
    #         ./nixng/phpweb.nix
    #       ];
    #     });
    #   };
    # });
    packages = nixpkgs.lib.genAttrs systems (system:
      let
        pkgs = ((nixpkgs.legacyPackages.${system}
          .extend phpComposerBuilder.overlays.default)
          .extend nix-snapshotter.overlays.default)
          .extend (final: prev: {
            nix2c = nix2container.packages.${system}.nix2container;
          });
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
        # phpweb-image = pkgs.nix-snapshotter.buildImage {
        phpweb-image = pkgs.nix2c.buildImage {
          name = "docteurklein/phpweb";
          maxLayers = 125;
          # resolvedByNix = true;
          config = {
            # Entrypoint = [ "${self.nixosConfigurations.${system}.phpweb.config.services.phpfpm.pools.main.phpPackage}/bin/php-fpm" ];
            # Entrypoint = [ "${self.nixosConfigurations.${system}.phpweb.config.system.build.toplevel}/init" ];
            Entrypoint = [ "${pkgs.dumb-init}/bin/dumb-init" "--" ];

            ExposedPorts = {
              "80/tcp" = {};
              "9000/tcp" = {};
            };
          };
          copyToRoot = pkgs.buildEnv {
            name = "root";
            paths = with pkgs; let 
              user = "phpweb";
              uid = 999;
              gid = 999;
            in [
              (writeTextDir "etc/shadow" ''
                root:!x:::::::
                ${user}:!:::::::
              '')
              (writeTextDir "etc/passwd" ''
                root:x:0:0::/root:/bin/sh
                nobody:x:99:99:nogroup:/:/sbin/nologin
                ${user}:x:${toString uid}:${toString gid}::/home/${user}:
              '')
              (writeTextDir "etc/group" ''
                root:x:0:
                nogroup:x:99:
                ${user}:x:${toString gid}:
              '')
              (writeTextDir "etc/gshadow" ''
                root:x::
                nobody:x::
                ${user}:x::
              '')
              coreutils
              procps
              bashInteractive
              nginx
              self.packages.${system}.phpweb-composer.php
              self.nixosConfigurations.${system}.phpweb.config.system.build.etc
            ];
            pathsToLink = [ "/bin" "/etc" ];
          };
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
            kubenix.modules.docker
            ./kubenix/modules/tfoutput.nix
            ./kubenix/modules/mkDeployment.nix
          ];

          kubernetes.resources.deployments.s1.spec.template.spec = {
            containers."s1-nginx" = {
              command = builtins.map (p: builtins.replaceStrings ["'"] [""] p) (lib.strings.splitString " "
                self.nixosConfigurations.${system}.phpweb.config.systemd.services.nginx.serviceConfig.ExecStart
              );
              volumeMounts = [
                { name = "var"; mountPath = "/var/log/nginx"; }
                { name = "tmp"; mountPath = "/tmp/nginx_client_body"; subPath = "nginx"; }
                { name = "run"; mountPath = "/run/nginx"; subPath = "nginx"; }
              ];
            };
            containers."s1-fpm" = {
              # command = ["/bin/sh" "-c" "while true; do echo '.'; sleep 1; done"];
              command = lib.strings.splitString " "
                self.nixosConfigurations.${system}.phpweb.config.systemd.services.phpfpm-main.serviceConfig.ExecStart
              ;
              volumeMounts = [
                { name = "tmp"; mountPath = "/tmp"; subPath = "fpm"; }
                { name = "run"; mountPath = "/run/phpfpm"; subPath = "fpm"; }
              ];
            };
            volumes = [
              { name = "tmp"; emptyDir = { sizeLimit = "500Mi"; }; }
              { name = "run"; emptyDir = { sizeLimit = "500Mi"; }; }
              { name = "var"; emptyDir = { sizeLimit = "500Mi"; }; }
            ];
          };

          # namespace = tfoutput.prefix.value;
          services = self.stack.${system}.services;
          # workers = self.stack.${system}.workers;

          docker = {
            registry.url = "docker.io";
            images.s1.image = self.packages.${system}.phpweb-image;
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

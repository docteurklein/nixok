{
  inputs.kubenix.url = "github:hall/kubenix";
  inputs.kubenix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nix2container.url = "github:nlewo/nix2container";
  #inputs.nix2container.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{self, nixpkgs, kubenix, nix2container, flake-parts, nixos-generators, ... }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem = { self', pkgs, system, config, ...}:
        let
          nix2containerPkgs = nix2container.packages.${system};
          c = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              ({ pkgs, config, lib, modulesPath, ... }: {

                imports = [
                  "${toString modulesPath}/virtualisation/docker-image.nix"
                ];

                boot.isContainer = true;
                services.journald.console = "/dev/console";
                nixos.useSystemd = true;
                nixos.configuration.boot.tmpOnTmpfs = true;
                nixos.configuration.services.nscd.enable = false;
                nixos.configuration.system.nssModules = lib.mkForce [];
                # nixos.configuration.systemd.services.nginx.serviceConfig.AmbientCapabilities =  lib.mkForce [
                #   "CAP_NET_BIND_SERVICE"
                # ];
                service.useHostStore = true;

                services.mysql.enable = true;
                services.mysql.package = pkgs.mysql;
                environment.systemPackages = with pkgs; [
                  bashInteractive
                  coreutils
                  stdenv
                  mysql
                ];
              })
            ];
          };
        in {
        packages = {
          nginx-image = nix2containerPkgs.nix2container.buildImage {
            name = "docteurklein/nginx";
            copyToRoot = pkgs.buildEnv {
              name = "root";
              paths = with pkgs; [
                c.config.system.build.toplevel
                bashInteractive
                coreutils
                stdenv
                mysql
              ];
              pathsToLink = [ "/bin" ];
            };

            config = {
              Cmd = [ "${pkgs.bash}/bin/bash" ];
              ExposedPorts = {
                "80/tcp" = {};
              };
            };
          };
          php-image = nix2containerPkgs.nix2container.buildImage {
            name = "docteurklein/php";
            config = {
              Cmd = [ "${pkgs.php}/bin/php-fpm" ];
              ExposedPorts = {
                "9000/tcp" = {};
              };
            };
          };
          manifest = (kubenix.evalModules.${system} {
            module = { kubenix, config, ... }: {
              imports = [
                kubenix.modules.docker
                ./modules/nginx.nix
                ./modules/php.nix
                ./modules/mysql.nix
              ];
              docker = {
                registry.url = "docker.io";
                images.nginx.image = self'.packages.nginx-image;
                images.php.image = self'.packages.php-image;
              };

              kubenix.project = "test1";
              kubernetes.version = "1.27";
            };
          }).config.kubernetes.result;
        };
        devShells = {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [ k3s kubectl skopeo phpactor ];
          };
        };
      };
    };
}

{
  inputs.kubenix = {
    url = "github:hall/kubenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nix2container = {
    url = "github:nlewo/nix2container";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nixng= {
    url = "github:nix-community/NixNG";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.systemFile = {
    url="path:./systems";
    flake=false;
  };

  outputs = inputs@{self, nixpkgs, nixng, kubenix, nix2container, ... }:
    let systems = [ "x86_64-linux"]; in {
    nixngConfigurations = nixpkgs.lib.genAttrs systems (system: {
      nginx = nixng.nglib.makeSystem {
        inherit system nixpkgs;
        name = "nixng";
        config = ({ pkgs, config, ... }: {
          dumb-init = {
            enable = true;
            type.services = { };
          };
          init.services.nginx = {
            shutdownOnExit = true;
            ensureSomething.link."documentRoot" = {
              src = "${pkgs.apacheHttpd}/htdocs";
              dst = "/var/www";
            };
          };
          services.nginx = {
            enable = true;
            envsubst = true;
            configuration = [
              {
                daemon = "off";
                worker_processes = 2;
                user = "nginx";

                events."" = {
                  use = "epoll";
                  worker_connections = 128;
                };

                error_log = [ "/dev/stderr" "info" ];
                pid = "/nginx.pid";

                http."" = {
                  server_tokens = "off";
                  include = "${pkgs.nginx}/conf/mime.types";
                  charset = "utf-8";

                  access_log = [ "/dev/stdout" "combined" ];

                  server."" = {
                    server_name = "localhost";
                    listen = "0.0.0.0:80";

                    location."/var/www" = {
                      root = "html";
                    };
                  };
                };
              }
            ];
          };
        });
      };
    });
    packages = nixpkgs.lib.genAttrs systems (system:
      let
        nix2containerPkgs = nix2container.packages.${system};
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        nginx-image = nix2containerPkgs.nix2container.buildImage {
          name = "docteurklein/nginx";
          config = {
            StopSignal = "SIGCONT";
            Entrypoint = [ "${self.nixngConfigurations.${system}.nginx.config.system.build.toplevel}/init" ];
            ExposedPorts = {
              "80/tcp" = {};
            };
          };
          maxLayers = 125;
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
              # ./modules/mysql.nix
            ];
            docker = {
              registry.url = "docker.io";
              images.nginx.image = self.packages.${system}.nginx-image;
              images.php.image = self.packages.${system}.php-image;
            };

            kubenix.project = "test1";
            kubernetes.version = "1.27";
          };
        }).config.kubernetes.result;
      }
    );
  };
}
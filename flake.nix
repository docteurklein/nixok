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
        phpComposer = import nixpkgs {
          inherit system;
          overlays = [
            phpComposerBuilder.overlays.default
          ];
        };
      in {
      phpweb = nixng.nglib.makeSystem {
        inherit system nixpkgs;
        name = "phpweb";
        config = ({ pkgs, config, ... }: {
          dumb-init = {
            enable = true;
            type.services = { };
          };

          init.services.apache2 = {
            shutdownOnExit = true;
            ensureSomething.create."documentRoot" = {
              type = "directory";
              mode = "750";
              # owner = "${cfg.user}:${cfg.group}";
              dst = "/var/www";
              persistent = false;
            };
          };

          # init.services.php-fpm-main.script = pkgs.writeShellScript "php-fpm-main-run" ''
          #   ${config.services.php-fpm-main.package}/bin/php-fpm
          # '';

          services.php-fpm = {
            pools = {
              main = {
                phpSettings = {
                  memory_limt = "64M";
                };
                package = pkgs.php.withExtensions({enabled, all}: enabled ++ [ all.imagick ]);
                # package = (phpComposer.api.buildComposerProject {
                #   src = ./php;
                #   php = phpComposer.api.buildPhpFromComposer { src = ./php; };
                #   pname = "test";
                #   version = "1.0.0-dev";
                #   vendorHash = "sha256-ZdxRo0tzoKXPXrgA4Q9Kc5JSEEoqcTV/uvMMMD1z7NI=";
                #   meta.mainProgram = "test";
                # });
                createUserGroup = false;
                fpmSettings = {
                  "pm" = "dynamic";
                  "pm.max_children" = 75;
                  "pm.start_servers" = 10;
                  "pm.min_spare_servers" = 5;
                  "pm.max_spare_servers" = 20;
                  "pm.max_requests" = 500;
                };
              };
            };
          };

          services.apache2 = {
            enable = true;
            envsubst = true;
            configuration = [
              {
                LoadModule = [
                  [ "mpm_event_module" "modules/mod_mpm_event.so" ]
                  [ "log_config_module" "modules/mod_log_config.so" ]
                  [ "unixd_module" "modules/mod_unixd.so" ]
                  [ "authz_core_module" "modules/mod_authz_core.so" ]
                  [ "dir_module" "modules/mod_dir.so" ]
                  [ "mime_module" "modules/mod_mime.so" ]
                  [ "proxy_module" "modules/mod_proxy.so" ]
                  [ "proxy_fcgi_module" "modules/mod_proxy_fcgi.so" ]
                ];
              }
              {
                Listen = "0.0.0.0:80";

                ServerRoot = "/var/www";
                ServerName = "httpd";
                PidFile = "/httpd.pid";

                DocumentRoot = "/var/www";

                User = "www-data";
                Group = "www-data";
              }

              {
                ErrorLog = "/dev/stderr";
                TransferLog = "/dev/stdout";

                LogLevel = "info";
              }

              {
                AddType = [
                  [ "image/svg+xml" "svg" "svgz" ]
                ];
                AddEncoding = [ "gzip" "svgz" ];

                TypesConfig = "${pkgs.apacheHttpd}/conf/mime.types";
              }

              {
                Directory = {
                  "/" = {
                    Require = [ "all" "denied" ];
                    Options = "SymlinksIfOwnerMatch";
                  };
                };

                VirtualHost = {
                  "*:80" = {
                    ProxyPassMatch =
                      [
                        "^/(.*\.php(/.*)?)$"
                        "unix:${config.services.php-fpm.pools.main.socket}|fcgi://localhost/var/www/"
                      ];

                    Directory = {
                      "/var/www" = {
                        Require = [ "all" "granted" ];
                        Options = [ "-Indexes" "+FollowSymlinks" ];
                        DirectoryIndex = "\${DIRECTORY_INDEX:-index.html}";
                      };
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
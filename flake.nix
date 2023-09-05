{
  inputs.kubenix = {
    url = "github:hall/kubenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nix2container = {
    url = "github:nlewo/nix2container";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.microvm = {
    url = "github:astro/microvm.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nixng= {
    url = "github:nix-community/NixNG";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{self, nixpkgs, nixng, kubenix, nix2container, nixos-generators, microvm, ... }:
    let systems = [ "x86_64-linux" "aarch64-linux"]; in {
    nixngConfigurations = nixpkgs.lib.genAttrs systems (system: {
      nginx = nixng.nglib.makeSystem {
          inherit system;
          modules = [
            microvm.nixosModules.microvm
            ({ pkgs, config, lib, modulesPath, ... }: {
              imports = [
                "${modulesPath}/profiles/minimal.nix"
              ];
              # nix.registry = {
              #   nixpkgs.flake = nixpkgs;
              #   self.flake = inputs.self;
              # };
              microvm = {
                # hypervisor = "firecracker";
                shares = [{
                  # use "virtiofs" for MicroVMs that are started by systemd
                  # proto = "9p";
                  tag = "ro-store";
                  # a host's /nix/store will be picked up so that the
                  # size of the /dev/vda can be reduced.
                  source = "/nix/store";
                  mountPoint = "/nix/.ro-store";
                }];
              };
              # boot.initrd.enable = true;
              # boot.modprobeConfig.enable = true;
              # boot.isContainer = true;
              # boot.postBootCommands = ''
              #   # Set virtualisation to docker
              #   echo "docker" > /run/systemd/container
              # '';

              # Iptables do not work in Docker.
              # networking.firewall.enable = false;

              # Socket activated ssh presents problem in Docker.
              # services.openssh.startWhenNeeded = false;
              # boot.specialFileSystems = lib.mkForce {};
              # boot.tmpOnTmpfs = true;
              networking.hostName = "";
              # services.journald.console = "/dev/console";
              # systemd.services.systemd-logind.enable = false;
              # systemd.services.console-getty.enable = false;
              # systemd.sockets.nix-daemon.enable = lib.mkDefault false;
              # systemd.services.nix-daemon.enable = lib.mkDefault false;

              # services.nscd.enable = false;
              # system.nssModules = lib.mkForce [];

              services.nginx.enable = true;
            })
          ];
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
            StopSignal = "SIGRTMIN+3";
            Entrypoint = [ "${self.nixosConfigurations.${system}.nginx.config.system.build.toplevel}/init" ];
            ExposedPorts = {
              "80/tcp" = {};
            };
          };
          maxLayers = 20;
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
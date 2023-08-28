{
  inputs.kubenix.url = "github:hall/kubenix";
  inputs.kubenix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = inputs@{self, nixpkgs, kubenix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      kube = (kubenix.evalModules.${system} {
        module = { kubenix, config, ... }: {
          imports = [
            kubenix.modules.docker
            ./modules/nginx.nix
            ./modules/php.nix
            ./modules/mysql.nix
          ];
          docker = {
            registry.url = "docker.io";
            images.nginx.image = self.packages.${system}.nginx-image;
            images.php.image = self.packages.${system}.php-image;
          };

          kubenix.project = "test1";
          kubernetes.version = "1.27";
        };
      });
    in {
      packages.${system} = {
        nginx-image = pkgs.dockerTools.buildLayeredImage {
          name = "docteurklein/nginx";
          contents = [ pkgs.nginx ];
          extraCommands = ''
            mkdir -p etc tmp/nginx_client_body
            chmod u+w etc
            echo "nginx:x:1000:1000::/:" > etc/passwd
            echo "nginx:x:1000:nginx" > etc/group
          '';
          config = {
            Cmd = [ "nginx" "-c" "/etc/nginx/nginx.conf" "-e" "stderr" ];
            ExposedPorts = {
              "80/tcp" = { };
            };
          };
        };
        php-image = pkgs.dockerTools.buildLayeredImage {
          name = "docteurklein/php";
          contents = [ pkgs.php ];
          config = {
            Cmd = [ "php-fpm" ];
            ExposedPorts = {
              "9000/tcp" = { };
            };
          };
        };
        manifest = kube.config.kubernetes.result;
        copy-images = kube.config.docker.copyScript;
      };
      apps.${system} = {
        copy-images = {
          type = "app";
          program = "${self.packages.${system}.copy-images}";
        };
      };
      devShells.${system} = {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [ k3s kubectl skopeo ];
        };
      };
    };
}

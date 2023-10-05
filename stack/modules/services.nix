{pkgs', config, lib, tfoutput, ...}: with lib; {

  options = with types; {
    services = mkOption {
      type = attrsOf (submodule {
        options = {
          kube = mkOption {
          };
          terraform = mkOption {
          };
          projects = mkOption {
            type = attrsOf (submodule {
              options = {
                regions = mkOption {
                  type = listOf str;
                };
              };
            });
          };
        };
      });
    };
  };

  config = {
    services.s1 = rec {
      kube = {
        enable = true;
        ports = [
          { name = "http"; port = 8080; }
        ];
        image = pkgs'.phpweb-image;
        env = [{
          name = "subscription";
          value = terraform.subscription;
        }];
      };
      terraform = {
        enable = true;
        subscription = tfoutput.s1.value.id;
      };
      projects.dev.regions = ["eu-west1"];
      projects.prod.regions = ["eu-west1" "us-east1"];
    };
    services.s2 = {
      kube.enable = false;
      terraform = {
        enable = true;
        subscription = tfoutput.s1.value.id;
      };
      projects.dev.regions = ["eu-west1"];
      projects.prod.regions = ["eu-west1" "us-east1"];
    };
  };
}

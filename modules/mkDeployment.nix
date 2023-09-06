{config, lib, kubenix, ...}: {
  imports = [ kubenix.modules.k8s ];

  options = {
    name = lib.mkOption {
      type = lib.types.str;
    };
  };

  # options.deployments = lib.mkOption {
  #   type = with lib.types; nullOr (enum [ ]);
  # };
  
  # options.services = lib.mkOption {
  #   type = with lib.types; nullOr (enum [ ]);
  # };

  config = {
    kubernetes.resources = {
      deployments.${config.name}.spec = {
        replicas = 2;
        selector.matchLabels.app = config.name;
        template = {
          metadata.labels.app = config.name;
          spec = {
            securityContext.fsGroup = 1000;
            containers.phpweb = {
              image = config.docker.images.${config.name}.path;
              imagePullPolicy = "IfNotPresent";
            };
          };
        };
      };
      services.${config.name}.spec = {
        selector.app = config.name;
        ports = [{
          name = "http";
          port = 80;
        }];
      };
    };
  };
}

{config, kubenix, lib, ...}: with lib; {
  imports = [ kubenix.modules.k8s ];

  options = {
    name = mkOption {
      type = types.str;
    };
    service = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      # ports = kubenix.;
    };
  };

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
      services.${config.name}.spec = mkIf config.service.enable {
        selector.app = config.name;
        # ports = config.service.ports;
      };
    };
  };
}

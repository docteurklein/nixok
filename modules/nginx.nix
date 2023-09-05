{ config, kubenix, ... }: {
  imports = [ kubenix.modules.k8s ];

  kubernetes.resources = {
    deployments.nginx.spec = {
      replicas = 2;
      selector.matchLabels.app = "nginx";
      template = {
        metadata.labels.app = "nginx";
        spec = {
          securityContext.fsGroup = 1000;
          containers.nginx = {
            image = config.docker.images.nginx.path;
            imagePullPolicy = "IfNotPresent";
          };
        };
      };
    };
    services.nginx.spec = {
      selector.app = "nginx";
      ports = [{
        name = "http";
        port = 80;
      }];
    };
  };
}

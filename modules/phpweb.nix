{ config, kubenix, ... }: {
  imports = [ kubenix.modules.k8s ];

  kubernetes.resources = {
    deployments.phpweb.spec = {
      replicas = 2;
      selector.matchLabels.app = "phpweb";
      template = {
        metadata.labels.app = "phpweb";
        spec = {
          securityContext.fsGroup = 1000;
          containers.phpweb = {
            image = config.docker.images.phpweb.path;
            imagePullPolicy = "IfNotPresent";
          };
        };
      };
    };
    services.phpweb.spec = {
      selector.app = "phpweb";
      ports = [{
        name = "http";
        port = 80;
      }];
    };
  };
}

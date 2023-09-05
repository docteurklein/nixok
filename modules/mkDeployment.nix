{config, kubenix, ...}: {
  imports = [ kubenix.modules.k8s ];
  config = {
    deployments.${config.name}.spec = {
      replicas = 2;
      selector.matchLabels.app = config.name;
      template = {
        metadata.labels.app = config.name;
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
      selector.app = config.name;
      ports = [{
        name = "http";
        port = 80;
      }];
    };
  };
}

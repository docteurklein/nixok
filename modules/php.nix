{ config, kubenix, ... }: {
  imports = [ kubenix.modules.k8s ];

  kubernetes.resources = {
    deployments.php.spec = {
      replicas = 2;
      selector.matchLabels.app = "php";
      template = {
        metadata.labels.app = "php";
        spec = {
          securityContext.fsGroup = 1000;
          containers.php = {
            image = config.docker.images.php.path;
            imagePullPolicy = "IfNotPresent";
          };
        };
      };
    };
    services.php.spec = {
      selector.app = "php";
      ports = [{
        name = "php";
        port = 9000;
      }];
    };
  };
}

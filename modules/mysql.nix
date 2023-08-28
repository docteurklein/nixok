{ config, kubenix, ... }: {
  imports = [ kubenix.modules.k8s ];

  kubernetes.resources = {
    deployments.mysql.spec = {
      replicas = 2;
      selector.matchLabels.app = "mysql";
      template = {
        metadata.labels.app = "mysql";
        spec = {
          #securityContext.fsGroup = 1000;
          containers.mysql = {
            image = "mysql:latest";
            imagePullPolicy = "IfNotPresent";
          };
        };
      };
    };
    services.mysql.spec = {
      selector.app = "mysql";
      ports = [{
        name = "mysql";
        port = 3306;
      }];
    };
  };
}

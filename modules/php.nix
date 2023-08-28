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
            volumeMounts = {
              "/etc/php".name = "config";
              "/var/lib/html".name = "static";
            };
          };
          volumes = {
            config.configMap.name = "php-config";
            static.configMap.name = "php-static";
          };
        };
      };
    };

    configMaps = {
      php-config.data."php.conf" = ''
        user php php;
        daemon off;
        error_log /dev/stdout info;
        pid /dev/null;
        events {}
        http {
          access_log /dev/stdout;
          server {
            listen 80;
            index index.html;
            location / {
              root /var/lib/html;
            }
          }
        }
      '';

      php-static.data."index.html" = ''
        <html><body><h1>Hello from php</h1></body></html>
      '';
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

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
            volumeMounts = {
              "/etc/nginx".name = "config";
              "/var/lib/html".name = "static";
              "/run".name = "tmp";
              "/run/lock".name = "tmp";
              "/tmp".name = "tmp";
              "/sys/fs/group" = {
                name = "cgroup";
                readOnly = true;
              };
            };
          };
          volumes = {
            config.configMap.name = "nginx-config";
            static.configMap.name = "nginx-static";
            tmp.emptyDir = {
              medium = "Memory";
              sizeLimit = "64Mi";
            };
            cgroup.hostPath = {
              path = "/sys/fs/cgroup";
              type = "Directory";
            };
          };
        };
      };
    };

    configMaps = {
      nginx-config.data."nginx.conf" = ''
        user nobody nobody;
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

      nginx-static.data."index.html" = ''
        <html><body><h1>Hello from NGINX</h1></body></html>
      '';
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

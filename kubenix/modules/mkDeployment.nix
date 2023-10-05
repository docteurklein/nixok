{ self, config, kubenix, lib, ...}: with lib; {
  imports = [ kubenix.modules.k8s ];

  options = with types; {
    services = mkOption {
      type = attrsOf (submodule {
        options = {
          enable = options.mkEnableOption "kubernetes manifests";
          image = mkOption {
            type = package;
          };
          ports = mkOption {
            type = listOf attrs;
            default = [];
          };
          env = mkOption {};
        };
      });
    };
  };
  
  config = {
    kubernetes.resources.deployments = builtins.mapAttrs (name: m: {
      spec = {
        replicas = 1;
        selector.matchLabels.app = name;
        template = {
          metadata = {
            annotations = {
              "profiles.grafana.com/cpu.port_name" = "http-metrics";
              "profiles.grafana.com/cpu.scrape" = "true";
              "profiles.grafana.com/memory.port_name" = "http-metrics";
              "profiles.grafana.com/memory.scrape" = "true";
            };
            labels.app = name;
          };
          spec = {
            dnsPolicy = "ClusterFirst";
            dnsConfig = {
              options = [{
                name = "ndots";
                value = "1";
              }];
            };
            securityContext = {
              runAsUser = 999;
              runAsGroup = 999;
              fsGroup = 999;
            };
            containers."${name}-nginx" = {
              # image = m.image.image;
              image = config.docker.images.${name}.path;
              imagePullPolicy = "IfNotPresent";
            };
            containers."${name}-fpm" = {
              image = config.docker.images.${name}.path;
              # image = m.image.image;
              imagePullPolicy = "IfNotPresent";
              env = m.env;
            };
          };
        };
      };
    }) config.services;

    kubernetes.resources.services = builtins.mapAttrs (name: m: {
      spec = {
        selector.app = name;
        ports = mkIf (length m.ports != 0) m.ports;
      };
    }) (lib.attrsets.filterAttrs (name: m: (length m.ports) > 0) config.services);
  };
}
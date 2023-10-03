{ self, config, kubenix, lib, ...}: with lib; {
  imports = [ kubenix.modules.k8s ];

  options = with types; {
    namespace = mkOption {
      type = nullOr str;
      default = null;
    };
    workers = mkOption {
      type = attrsOf (submodule {
        options = {
          name = mkOption {
            type = str;
          };
          namespace = mkOption {
            type = nullOr str;
            default = null;
          };
          subscription = mkOption {
            type = str;
          };
        };
      });
    };
    services = mkOption {
      type = attrsOf (submodule {
        options = {
          name = mkOption {
            type = str;
          };
          image = mkOption {
            type = package;
          };
          namespace = mkOption {
            type = nullOr str;
            default = null;
          };
          ports = mkOption {
            type = listOf attrs;
            default = [];
          };
        };
      });
    };
  };
  
  config = {
    kubernetes.resources.deployments = builtins.mapAttrs (name: m:
    let ns = config.namespace or m.namespace;
    in {
      metadata.namespace = mkIf (!isNull ns) ns;
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
            namespace = mkIf (!isNull ns) ns;
          };
          spec = {
            securityContext.fsGroup = 1000;
            # containers."${name}-nginx" = {
            #   image = m.image.image;
            #   imagePullPolicy = "IfNotPresent";
            # };
            containers."${name}-fpm" = {
              # image = config.docker.images.${name}.path;
              image = m.image.image;
              imagePullPolicy = "IfNotPresent";
            };
          };
        };
      };
    }) (config.services); # // config.workers);

    kubernetes.resources.services = builtins.mapAttrs (name: m:
    let ns = config.namespace or m.namespace;
    in {
      metadata.namespace = mkIf (!isNull ns) ns;
      spec = {
        selector.app = name;
        ports = mkIf (length m.ports != 0) m.ports;
      };
    }) (lib.attrsets.filterAttrs (name: m: (length m.ports) > 0) config.services);
  };
}
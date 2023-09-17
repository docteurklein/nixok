{config, kubenix, lib, ...}: with lib; {
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
          namespace = mkOption {
            type = nullOr str;
            default = null;
          };
          service = {
            enable = mkOption {
              type = bool;
              default = true;
            };
            ports = mkOption {
              type = listOf attrs;
              default = [];
            };
          };
        };
      });
    };
  };
  
  config = {
    kubernetes.resources.deployments = builtins.mapAttrs (name: m:
    let ns = config.namespace or m.namespace;
    in {
      spec = {
        replicas = 2;
        selector.matchLabels.app = name;
        template = {
          metadata.labels.app = name;
          metadata.namespace = mkIf (!isNull ns) ns;
          spec = {
            securityContext.fsGroup = 1000;
            containers.${name} = {
              image = config.docker.images.${name}.path;
              imagePullPolicy = "IfNotPresent";
              env = [] ++ (if m ? subscription then [{
                name = "subscription";
                value = m.subscription;
              }] else []);
            };
          };
        };
      };
    }) (config.services // config.workers);

    kubernetes.resources.services = builtins.mapAttrs (name: m:
    let ns = config.namespace or m.namespace;
    in {
      metadata.namespace = mkIf (!isNull ns) ns;
      spec = {
        selector.app = name;
        ports = mkIf (length m.service.ports != 0) m.service.ports;
      };
    }) (lib.attrsets.filterAttrs (name: m: m.service.enable) config.services);
  };
}
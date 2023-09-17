{ config, lib, ... }: with lib; {

  options = with types; {
    workers = mkOption {
      type = attrsOf (submodule {
        options = {
          subscription = mkOption {
            type = str;
          };
        };
      });
    };
  };

  config = {
    resource.null_resource = builtins.mapAttrs (name: m: {
      provisioner."local-exec" = {
        command = "echo \${var.prefix}-${name}";
      };
      triggers = {
        prefix = lib.tfRef "var.prefix";
      };
    }) config.workers;

    variable.prefix = {
      type = "string";
    };

    output = (builtins.mapAttrs (name: m: {
      value = lib.tfRef "resource.null_resource.${name}";
    }) config.workers) // {
      prefix = { value = lib.tfRef "var.prefix"; };
    };
  };
}

{config, lib, tfAst, ...}: with lib; {
  imports = [];

  options.tfoutput = builtins.mapAttrs (k: v: {
    value = mkOption {
      type = types.nullOr (types.oneOf [ types.str types.int types.bool types.float ]);
    };
    sensitive = mkOption {
      type = types.bool;
    };
    type = mkOption {
      type = types.str;
    };
  }) tfAst.config.output;
}

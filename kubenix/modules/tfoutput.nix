{config, lib, tfAst ? null, ...}: with lib; {
  imports = [];

  options = {
    tfoutput = builtins.mapAttrs (mkOption {
      type = types.nullOr (types.oneOf [ types.str types.int types.bool types.float ]);
    }) tfAst.config.output;
  };

  config.namespace = tfAst.config.output.test.value;
}

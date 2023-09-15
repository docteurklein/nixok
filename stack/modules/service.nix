{config, lib, ...}: with lib; {
  options = {
    services = mkOption {
      type = types.attrsOf types.attrs;
    };
  };
}

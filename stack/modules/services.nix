{config, lib, ...}: with lib; {
  options = {
    services = mkOption {
      type = types.attrsOf types.attrs;
    };
  };
  config = {
    services.s1 = {};
    services.s2 = {};
  };
}

{config, lib, ...}: with lib; {
  options = {
    services = mkOption {
      type = types.attrsOf types.attrs;
    };
  };
  config = {
    services.s1 = {
      service.ports = [
        { name = "http"; port = 80; }
      ];
    };
    services.s2 = {};
  };
}

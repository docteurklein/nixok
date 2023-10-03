{self, config, lib, ...}: with lib; {
  options = {
    services = mkOption {
      type = types.attrsOf types.attrs;
    };
  };
  config = {
    services.s1 = {
      ports = [
        { name = "http"; port = 80; }
      ];
      image = self.phpweb-image;
    };
    # services.s2 = {};
  };
}

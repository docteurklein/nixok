{config, lib, ...}: with lib; {
  options = {
    workers = mkOption {
      type = types.attrsOf types.attrs;
    };
  };
  config = {
    workers.w1 = { subscription = "w1"; };
    workers.w2 = { subscription = "w2"; };
  };
}

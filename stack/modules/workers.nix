{config, lib, tfoutput, ...}: with lib; {
  options = {
    workers = mkOption {
      type = types.attrsOf types.attrs;
    };
  };
  config = {
    workers.w1 = { subscription = tfoutput.w1.value.id; }; # @FIXME silly example
    workers.w2 = { subscription = tfoutput.w2.value.id; };
    workers.w3 = { subscription = tfoutput.w3.value.id; };
  };
}

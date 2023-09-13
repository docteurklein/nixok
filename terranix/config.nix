{ config, lib, ... }: {
  #resource.google_compute_network.vpc_network = {
  #  name = "\${var.prefix}-terraform-network";
  #};

  resource.null_resource.test = {
    provisioner."local-exec" = {
      command = "echo \${var.prefix}; date";
    };
    triggers = {
      prefix = lib.tfRef "var.prefix";
    };
  };

  output.test.value = lib.tfRef "null_resource.test.id";

  variable.prefix = {
    type = "string";
  };
}

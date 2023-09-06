{ config, terranix, ... }: {
  imports = [
  ];
  provider.google = {
    project = "akceld-prd-pim-saas-dev";
    region = "europe-west-2";
    zone = "europe-west-2-a";
  };

  resource.google_compute_network.vpc_network = {
    name = "terraform-network";
  };
}
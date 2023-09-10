{ config, ...}: {
  imports = [
    ./mkDeployment.nix
  ];
  name = "phpweb";
  kubernetes.resources.services.${config.name}.spec.ports = [
    { name = "http"; port = 80; }
  ];
}
{...}: rec {
  imports = [
    ./kubenix/modules/mkDeployment.nix
  ];
  name = "phpweb";
  kubernetes.resources.services.${name}.spec.ports = [
    { name = "http"; port = 80; }
  ];
}
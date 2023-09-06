{
  imports = [  ../../modules/mkDeployment.nix ];
  name = "phpweb";
  kubernetes.resources.services.phpweb.spec.ports = [
    { name = "http"; port = 80; }
  ];
}
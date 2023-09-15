{ config, ...}: {
  imports = [
    ./mkDeployment.nix
  ];

  mod = [
    { name = "phpweb"; }
    { name = "phpweb2"; }
  ];
}

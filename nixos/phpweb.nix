{  config, pkgs, lib, ... }: {

  options.name = lib.mkOption {
    type = lib.types.str;
    default = "phpweb";
  };
  options.package = lib.mkOption {
    type = lib.types.package;
  };

  config.services.nginx = {
    enable = true;
    virtualHosts.${config.name}.locations."/" = {
      root = "${config.package}/share/php/${config.name}/public";
      extraConfig = ''
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass localhost:9000;
        include ${pkgs.nginx}/conf/fastcgi_params;
        include ${pkgs.nginx}/conf/fastcgi.conf;
      '';
     };
  };

  config.services.phpfpm = {
    phpOptions = ''
      memory_limt = 64M;
      opcache.enable_cli=1;
      opcache.jit=function;
      opcache.jit_buffer_size=64M;
      opcache.jit_debug=0x30;
    '';
    pools = {
      main = {
        user = config.name;
        group = config.name;
        phpPackage = config.package.php;
        settings = {
          "pm" = "dynamic";
          "pm.max_children" = 75;
          "pm.start_servers" = 10;
          "pm.min_spare_servers" = 5;
          "pm.max_spare_servers" = 20;
          "pm.max_requests" = 500;
        };
      };
    };
  };

  config = {
    users.users.${config.name} = {
      isSystemUser = true;
      createHome = false;
      group  = config.name;
    };
    users.groups.${config.name} = {};

    environment.systemPackages = [
      config.package.php
    ];
  };
}

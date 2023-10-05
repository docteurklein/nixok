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
    defaultHTTPListenPort = 8080;
    user = config.name;
    group = config.name;
    virtualHosts.${config.name}.locations."/" = {
      root = "${config.package}/share/php/${config.name}/public";
      extraConfig = ''
        location / {
          try_files $uri $uri/ /index.php$is_args$args;
        }

        location ~ \.php$ {
          fastcgi_split_path_info ^(.+\.php)(/.+)$;
          fastcgi_pass localhost:9000;
          include ${pkgs.nginx}/conf/fastcgi_params;
          include ${pkgs.nginx}/conf/fastcgi.conf;
        }
      '';
     };
  };

  config.services.phpfpm = {
    pools = {
      main = {
        listen = "127.0.0.1:9000";
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

  };
}

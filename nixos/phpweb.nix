{  config, pkgs, lib, ... }: {

  options.name = lib.mkOption {
    type = lib.types.str;
    default = "phpweb";
  };

  config = {
    services.phpfpm.pools.${config.name} = {
      user = config.name;
      settings = {
        "listen.owner" = config.services.nginx.user;
        "pm" = "dynamic";
        "pm.max_children" = 32;
        "pm.max_requests" = 500;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 2;
        "pm.max_spare_servers" = 5;
        "php_admin_value[error_log]" = "stderr";
        "php_admin_flag[log_errors]" = true;
        "catch_workers_output" = true;
      };
      phpEnv."PATH" = lib.makeBinPath [ pkgs.php ];
    };

    services.nginx = {
      enable = true;
      virtualHosts."*:80".locations."/" = {
        root = "/";
        extraConfig = ''
          fastcgi_split_path_info ^(.+\.php)(/.+)$;
          fastcgi_pass unix:${config.services.phpfpm.pools.${config.name}.socket};
          include ${pkgs.nginx}/conf/fastcgi_params;
          include ${pkgs.nginx}/conf/fastcgi.conf;
        '';
       };
    };
    users.users.${config.name} = {
      isSystemUser = true;
      createHome = false;
      group  = config.name;
    };
    users.groups.${config.name} = {};
  };
}

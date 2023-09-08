{  config, pkgs, lib, ... }: {
  dumb-init = {
    enable = true;
    type.services = { };
  };

  init.services.apache2 = {
    shutdownOnExit = true;
    ensureSomething.create."ServerRoot" = {
      type = "directory";
      mode = "750";
      dst = "/usr/local/apache";
      persistent = true; # ATTENTION: "false" would delete all the contents, so don't mount $PWD for example :)
    };
  };

  services.php-fpm = {
    pools = {
      main = {
        phpSettings = {
          memory_limt = "64M";
        };
        # package = pkgs.php.withExtensions({enabled, all}: enabled ++ [ all.imagick ]);
        createUserGroup = false;
        fpmSettings = {
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

  services.apache2 = {
    enable = true;
    envsubst = true;
    configuration = [
      {
        LoadModule = [
          [ "mpm_event_module" "modules/mod_mpm_event.so" ]
          [ "log_config_module" "modules/mod_log_config.so" ]
          [ "unixd_module" "modules/mod_unixd.so" ]
          [ "authz_core_module" "modules/mod_authz_core.so" ]
          [ "dir_module" "modules/mod_dir.so" ]
          [ "mime_module" "modules/mod_mime.so" ]
          [ "proxy_module" "modules/mod_proxy.so" ]
          [ "proxy_fcgi_module" "modules/mod_proxy_fcgi.so" ]
        ];
      }
      {
        Listen = "0.0.0.0:80";

        ServerName = "httpd";
        PidFile = "/httpd.pid";

        DocumentRoot = "${config.services.php-fpm.pools.main.package}/share/php/phpweb";

        User = "www-data";
        Group = "www-data";
      }

      {
        ErrorLog = "/dev/stderr";
        TransferLog = "/dev/stdout";

        LogLevel = "info";
      }

      {
        AddType = [
          [ "image/svg+xml" "svg" "svgz" ]
        ];
        AddEncoding = [ "gzip" "svgz" ];

        TypesConfig = "${pkgs.apacheHttpd}/conf/mime.types";
      }

      {
        Directory = {
          "/" = {
            Require = [ "all" "denied" ];
            Options = "SymlinksIfOwnerMatch";
          };
        };

        VirtualHost."*:80".ProxyPassMatch = [
          "^/(.*\.php(/.*)?)$"
          "unix:${config.services.php-fpm.pools.main.socket}|fcgi://localhost/${config.services.php-fpm.pools.main.package}/share/php/phpweb"
        ];
      }
    ];
  };
}

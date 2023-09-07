{  config, pkgs, lib, ... }: {

  options.package = lib.mkOption {
    type = lib.types.package;
  };

  config = {
    dumb-init = {
      enable = true;
      type.services = { };
    };

    init.services.apache2 = {
      shutdownOnExit = true;
      # ensureSomething.create."documentRoot" = {
      #   type = "directory";
      #   mode = "750";
      #   # owner = "${cfg.user}:${cfg.group}";
      #   dst = "/var/www";
      #   persistent = true;
      # };
    };

    init.services.php-fpm-main.script = lib.mkForce (pkgs.writeShellScript "php-fpm-main-run" ''
      ${config.package.php}/bin/php-fpm
    '');

    services.php-fpm = {
      pools = {
        main = {
          phpSettings = {
            memory_limt = "64M";
          };
          # package = pkgs.php.withExtensions({enabled, all}: enabled ++ [ all.imagick ]);
          package = config.package;
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

          ServerRoot = "/var/www";
          ServerName = "httpd";
          PidFile = "/httpd.pid";

          DocumentRoot = "/var/www";

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

          VirtualHost = {
            "*:80" = {
              ProxyPassMatch =
                [
                  "^/(.*\.php(/.*)?)$"
                  "unix:${config.services.php-fpm.pools.main.socket}|fcgi://localhost/var/www/"
                ];

              Directory = {
                "/var/www" = {
                  Require = [ "all" "granted" ];
                  Options = [ "-Indexes" "+FollowSymlinks" ];
                  DirectoryIndex = "\${DIRECTORY_INDEX:-index.html}";
                };
              };
            };
          };
        }
      ];
    };
  };
}
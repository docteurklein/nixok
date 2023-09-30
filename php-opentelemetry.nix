{ buildPecl, lib, ... }:
buildPecl {
  pname = "opentelemetry";
  version = "1.0.0RC1";
  sha256 = "sha256-21zfeG6Ptd66bengyc4D6uBMhjFBJ5sSrF735Y7u6UM=";

  meta = with lib; {
    description = "OpenTelemetry PHP auto-instrumentation extension";
    license = licenses.php301;
    homepage = "https://github.com/open-telemetry/opentelemetry-php-instrumentation";
    # maintainers = teams.php.members;
    platforms = platforms.linux;
  };
}
{ config, lib, ... }:
{
  org.modules.home.work-ssl-certs =
    { pkgs, ... }:
    let
      customCacert = pkgs.cacert.override {
        extraCertificateFiles = config.org.ssl.extraCertificateFiles;
      };
      bundle = "${customCacert}/etc/ssl/certs/ca-bundle.crt";
    in
    lib.mkIf config.org.ssl.enable {
      home.sessionVariables = {
        SSL_CERT_FILE = bundle;
        CURL_CA_BUNDLE = bundle;
        REQUESTS_CA_BUNDLE = bundle;
        NODE_EXTRA_CA_CERTS = bundle;
        NODE_OPTIONS = "--use-openssl-ca";
      };

      programs.git.settings.http.sslCAInfo = bundle;
    };
}

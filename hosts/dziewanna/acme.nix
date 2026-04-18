{ ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "alex.wicks1@gmail.com";
      listenHTTP = ":80";
    };
  };

  security.acme.certs."mumble.awicks.io" = {
    reloadServices = [ "murmur.service" ];
    group = "murmur";
  };
}

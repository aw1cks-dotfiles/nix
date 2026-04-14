{ config, pkgs, ... }:
{
  services.murmur = {
    enable = true;
    welcometext = "<br />Welcome to <strong>Alex's Mumble server</strong><br />";

    users = 100;
    bandwidth = 130000;
    sendVersion = true;
    clientCertRequired = true;

    allowHtml = true;
    textMsgLength = 0;
    imgMsgLength = 0;

    autobanAttempts = 0;
    autobanTimeframe = 0;

    extraConfig = ''
      listenersperchannel=0
      listenersperuser=0

      suggestPushToTalk=true

      messageburst=9999
      messagelimit=9999
    '';

    sslKey = "${config.security.acme.certs."mumble.awicks.io".directory}/key.pem";
    sslCert = "${config.security.acme.certs."mumble.awicks.io".directory}/fullchain.pem";
  };

  # Allow murmur traffic and HTTP for ACME challenge
  networking.firewall.allowedTCPPorts = [ 64738 80 ];
  networking.firewall.allowedUDPPorts = [ 64738 ];

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

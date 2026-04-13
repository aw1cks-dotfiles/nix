{ lib, ... }:
{
  options.org = {
    domain = lib.mkOption {
      type = lib.types.singleLineStr;
      default = "example.internal";
      description = "Example internal domain used by the layered template modules.";
    };

    modules.home = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = { };
      description = "Named downstream home-manager deferred modules.";
    };

    profiles.home = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = { };
      description = "Named downstream home-manager profiles built from org.modules.home.";
    };

    ssl.enable = lib.mkEnableOption "an internal CA bundle layered on top of the shared home-manager stack";

    ssl.extraCertificateFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Additional PEM or CRT files to append to the system CA bundle for internal tooling.";
    };
  };

  config = {
    aw1cks.identities.work = {
      fullName = "Your Name";
      email = "your.name@example.internal";
      username = "your.name";
      homeDirectory = "/home/your.name";
    };

    # Uncomment this if most of the repo should use the work identity by default.
    # aw1cks.identity.default = "work";
  };
}

{ ... }:
{
  aw1cks.modules.home.gpg =
    { pkgs, ... }:
    let
      pinentryPackage = if pkgs.stdenv.isDarwin then pkgs.pinentry_mac else pkgs.pinentry-tty;
      pinentryProgram = if pkgs.stdenv.isDarwin then "pinentry-mac" else "pinentry";
    in
    {
      home.packages = [ pinentryPackage ];

      home.sessionVariables = {
        PINENTRY_USER_DATA = "USE_TTY=$(tty)";
      };

      services.gpg-agent = {
        enable = true;
        pinentry.package = pinentryPackage;
        pinentry.program = pinentryProgram;
      };
    };
}

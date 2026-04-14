{ pkgs, ... }:
{
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "en_GB.UTF-8/UTF-8"
    "pl_PL.UTF-8/UTF-8"
    "de_DE.UTF-8/UTF-8"
    "fr_FR.UTF-8/UTF-8"
    "ru_RU.UTF-8/UTF-8"
  ];
  i18n.defaultLocale = "en_US.UTF-8";

  time.timeZone = "Europe/London";
}

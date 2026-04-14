{ config, lib, pkgs, ... }:
let
  plymouthEnabled = ((!config.my.system.isVmBuild) && (config.my.system.type == "desktop"));
in
{
  imports = [
    ./efi.nix
    ./systemd-boot.nix
  ];

  boot = {
    loader.timeout = 0;

    bootspec.enable = true;

    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = lib.optionals plymouthEnabled [
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=0"
      "boot.shell_on_fail"
    ];
    consoleLogLevel = if plymouthEnabled then 0 else 3;

    initrd = {
      verbose = false;
      systemd.enable = true;
    };

    plymouth = {
      enable = plymouthEnabled;
      theme = "rings";
      themePackages = with pkgs; [
        # By default we would install all themes
        (adi1090x-plymouth-themes.override {
          selected_themes = [ "rings" ];
        })
      ];
    };

    tmp.cleanOnBoot = true;
  };
}

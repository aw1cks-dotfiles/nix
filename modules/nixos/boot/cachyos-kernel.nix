{ inputs, lib, ... }:
let
  validVariants = [
    "latest"
    "lts"
  ];
  validMarches = [
    "default"
    "x86_64-v2"
    "x86_64-v3"
    "x86_64-v4"
    "zen4"
  ];

  mkAttrName =
    {
      variant,
      lto,
      march,
    }:
    let
      ltoSuffix = if lto then "-lto" else "";
      marchSuffix = if march == "default" then "" else "-${march}";
    in
    "linuxPackages-cachyos-${variant}${ltoSuffix}${marchSuffix}";
in
{
  # CachyOS prebuilt kernel via xddxdd/nix-cachyos-kernel.
  #
  # PLAIN-ATTRSET form (not a function) so that multiple deferred-module
  # evaluation paths get the same identity and the module system
  # deduplicates option declarations correctly. The nested function-form
  # module inside `imports` is what reads pkgs/config; the attrset wrapper
  # is what gets cached/deduplicated.
  aw1cks.modules.nixos.cachyos-kernel = {
    options.aw1cks.cachyosKernel = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to set boot.kernelPackages to the selected CachyOS kernel
          variant. Default false so importing the module is a no-op until a
          consumer (typically the desktop-perf glue or a host) flips it on.
        '';
      };

      variant = lib.mkOption {
        type = lib.types.enum validVariants;
        default = "latest";
        description = "CachyOS kernel series. `latest` = mainline, `lts` = LTS branch.";
      };

      lto = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use the ThinLTO-built variant. Free win, no rebuild cost.";
      };

      march = lib.mkOption {
        type = lib.types.enum validMarches;
        default = "default";
        description = ''
          x86-64 microarch level the kernel is compiled for.

          - "default": baseline, runs on anything.
          - "x86_64-v2": SSE4.2-class. Floor for any post-2010 CPU.
          - "x86_64-v3": AVX2/FMA/BMI2. Correct choice for Zen 2/3 (Ryzen
            3000/5000), Haswell+. Free win on kernel hot paths (crypto,
            copy_*_user, reclaim). WILL NOT BOOT on pre-Haswell or pre-Zen2.
          - "x86_64-v4": AVX-512. Zen 4+/Skylake-X+ only. Refuses to boot
            on Zen 3.
          - "zen4": znver4 microarch tuning. Zen 4+ only.

          Verify with: /lib/ld-linux-x86-64.so.2 --help | grep supported
        '';
      };
    };

    imports = [
      (
        {
          config,
          pkgs,
          lib,
          ...
        }:
        let
          cfg = config.aw1cks.cachyosKernel;
          attr = mkAttrName {
            inherit (cfg) variant lto march;
          };
          kernelSet = inputs.nix-cachyos-kernel.legacyPackages.${pkgs.stdenv.hostPlatform.system};
        in
        {
          config = lib.mkIf cfg.enable {
            assertions = [
              {
                assertion = builtins.hasAttr attr kernelSet;
                message = "aw1cks.cachyosKernel: variant=${cfg.variant} lto=${builtins.toString cfg.lto} march=${cfg.march} resolves to nonexistent attribute ${attr}. See nix-cachyos-kernel/release/kernel-cachyos/default.nix for the supported matrix.";
              }
            ];

            boot.kernelPackages = kernelSet.${attr};
          };
        }
      )
    ];
  };
}

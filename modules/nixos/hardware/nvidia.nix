{ ... }:
{
  aw1cks.modules.nixos.nvidia =
    { pkgs, ... }:
    {
      nix.settings = {
        substituters = [ "https://cuda-maintainers.cachix.org" ];
        trusted-public-keys = [
          "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        ];
      };

      services.xserver.videoDrivers = [ "nvidia" ];
      boot.blacklistedKernelModules = [ "nouveau" ];

      boot.kernelParams = [
        "nvidia-drm.modeset=1"
        "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      ];

      environment.variables = {
        LIBVA_DRIVER_NAME = "nvidia";
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      };

      hardware.nvidia = {
        nvidiaSettings = true;
        powerManagement = {
          enable = true;
        };
        modesetting.enable = true;
        forceFullCompositionPipeline = true;
      };

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          nvidia-vaapi-driver
          libva-vdpau-driver
          libvdpau-va-gl
          egl-wayland
          vulkan-loader
          vulkan-validation-layers
          libva
        ];
      };

      environment.systemPackages = with pkgs; [
        libva-utils
        mesa-demos
        vulkan-tools
      ];
    };
}

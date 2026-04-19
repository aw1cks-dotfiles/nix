{ ... }:
{
  aw1cks.modules.nixos.nvidia =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    {
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
        package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.production;
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

{ pkgs, config, ... }:
{
  nixpkgs.config = {
    nvidia.acceptLicense = true;
    allowUnfree = true;
  };
  # Nix cache for CUDA
  nix.settings = {
    substituters = ["https://cuda-maintainers.cachix.org"];
    trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  boot.blacklistedKernelModules = ["nouveau"];

  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    # "nvidia.NVreg_RegistryDwords=PowerMizerEnable=0x1;PerfLevelSrc=0x2222;PowerMizerLevel=0x3;PowerMizerDefault=0x3;PowerMizerDefaultAC=0x3"
  ];

  environment.variables = {
    LIBVA_DRIVER_NAME = "nvidia"; # Hardware video acceleration
    GBM_BACKEND = "nvidia-drm"; # Graphics backend for Wayland
    __GLX_VENDOR_LIBRARY_NAME = "nvidia"; # Use Nvidia driver for GLX
    WLR_NO_HARDWARE_CURSORS = "1"; # Fix for cursors on Wayland
    __GL_GSYNC_ALLOWED = "1"; # Enable G-Sync if available
    __GL_VRR_ALLOWED = "1"; # Enable VRR (Variable Refresh Rate)
    WLR_DRM_NO_ATOMIC = "1"; # Fix for some issues with Hyprland
    NVD_BACKEND = "direct"; # Configuration for new driver
  };

  hardware = {
    nvidia = {
      open = false; # Proprietary driver for better performance
      nvidiaSettings = true; # Nvidia settings utility
      powerManagement = {
        enable = true; # Power management
        finegrained = true; # More precise power consumption control
      };
      modesetting.enable = true; # Required for Wayland
      forceFullCompositionPipeline = true; # Prevents screen tearing
    };

    # Enhanced graphics support
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        vaapiVdpau
        libvdpau-va-gl
        mesa
        egl-wayland
        vulkan-loader
        vulkan-validation-layers
        libva
      ];
    };
  };

  # Additional useful packages
  environment.systemPackages = with pkgs; [
    vulkan-tools
    glxinfo
    libva-utils # VA-API debugging tools
  ];
}

{ ... }:
{
  environment.variables = {
    XDG_SESSION_TYPE = "wayland"; # Force Wayland
    NIXOS_OZONE_WL = "1"; # Wayland support for Electron apps
    MOZ_ENABLE_WAYLAND = "1"; # Wayland support for Firefox
  };
}

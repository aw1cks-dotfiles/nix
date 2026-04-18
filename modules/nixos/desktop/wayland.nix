{ ... }:
{
  aw1cks.modules.nixos.wayland = {
    environment.variables = {
      XDG_SESSION_TYPE = "wayland";
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
    };
  };
}

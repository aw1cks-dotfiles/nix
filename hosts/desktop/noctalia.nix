{ ... }:
{
  # Noctalia's shell integrations expect these system services to exist.
  hardware.bluetooth.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
}

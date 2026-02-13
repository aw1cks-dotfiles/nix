# Workstation composite aspect — includes all workstation sub-aspects
{ dl, den, ... }:
{
  dl.workstation = {
    includes = [
      dl.workstation-zen-browser
      dl.workstation-gui-apps
    ];
  };
}

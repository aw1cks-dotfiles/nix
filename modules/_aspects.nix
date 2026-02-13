# Conditionally import all den aspects only when den is available
{ inputs, lib, ... }:
{
  imports = lib.optionals (inputs ? den) [
    ./_aspects/base/nixpkgs.nix
    ./_aspects/base/home-manager.nix
    ./_aspects/base/nix-settings.nix
    ./_aspects/base/cli-tools.nix
    ./_aspects/base/git.nix
    ./_aspects/base/default.nix
    ./_aspects/development/dev-tools.nix
    ./_aspects/development/ai.nix
    ./_aspects/development/containers.nix
    ./_aspects/development/rust.nix
    ./_aspects/development/kubernetes.nix
    ./_aspects/development/java.nix
    ./_aspects/development/default.nix
    ./_aspects/workstation/zen-browser.nix
    ./_aspects/workstation/gui-apps.nix
    ./_aspects/workstation/default.nix
  ];
}

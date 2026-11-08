{
  inputs,
  lib,
  pkgs,
  languageServersModule,
}:
let
  renderedHome = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      languageServersModule
      {
        home.username = "clangd-policy-check";
        home.homeDirectory =
          if pkgs.stdenv.hostPlatform.isDarwin then
            "/Users/clangd-policy-check"
          else
            "/build/clangd-policy-check";
        home.stateVersion = "25.05";
        home.packages = lib.mkForce [ ];
      }
    ];
  };
in
pkgs.runCommand "clangd-policy-check"
  {
    nativeBuildInputs = [ pkgs.python3 ];
    renderedHome = renderedHome.config.home-files;
    clangd = "${pkgs.clang-tools}/bin/clangd";
  }
  ''
    python3 ${./_clangd-policy-check.py}
    touch "$out"
  ''

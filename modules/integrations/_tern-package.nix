{ pkgs }:
let
  sources = import ./_tern-sources.nix;
  system = pkgs.stdenv.hostPlatform.system;
  artifact = sources.artifacts.${system} or (throw "Tern has no pinned binary for ${system}");
  src = pkgs.requireFile {
    inherit (artifact) name hash;
    url = "https://build.stencil.so/tern";
  };
  backend = if pkgs.stdenv.hostPlatform.isDarwin then ./_tern-darwin.nix else ./_tern-linux.nix;
in
import backend {
  inherit pkgs src;
  inherit (sources) version;
  meta = {
    description = "Native multiplexing terminal with persistent sessions";
    homepage = "https://stencil.so/tern";
    license = pkgs.lib.licenses.unfree;
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
    mainProgram = "tern";
    platforms = builtins.attrNames sources.artifacts;
    # Authenticated proprietary artifacts are not public CI inputs.
    hydraPlatforms = [ ];
  };
}

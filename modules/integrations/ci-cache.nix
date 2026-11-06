{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      omp = inputs.oh-my-pi.packages.${system}.omp;
      publisher = pkgs.writeShellApplication {
        name = "publish-ci-cache";
        runtimeInputs = [
          pkgs.lixPackageSets.latest.lix
          pkgs.cachix
        ];
        text = ''
          usage="usage: publish-ci-cache [-h] cache"
          case "''${1:-}" in
            -h|--help)
              echo "$usage"
              echo "Build and publish this flake's explicit CI cache closure."
              exit 0
              ;;
            --) shift ;;
            -*)
              echo "$usage" >&2
              exit 2
              ;;
          esac
          if [ "$#" -ne 1 ]; then
            echo "$usage" >&2
            exit 2
          fi
          if [ -z "''${CACHIX_AUTH_TOKEN:-}" ]; then
            echo "publish-ci-cache: Set the cache-scoped CACHIX_AUTH_TOKEN environment variable" >&2
            exit 2
          fi

          cache_root="$(
            # Only Cachix receives publishing credentials, not the Nix build.
            unset CACHIX_AUTH_TOKEN CACHIX_SIGNING_KEY
            nix build .#ci-cache \
              --accept-flake-config \
              --no-update-lock-file \
              --no-link \
              --print-out-paths
          )"
          exec cachix push "$1" "$cache_root"
        '';
      };
    in
    {
      # OMP's runtime closure omits expensive build-only native and Cargo artifacts.
      packages.ci-cache = pkgs.linkFarm "ci-cache" [
        {
          name = "omp";
          path = omp;
        }
        {
          name = "omp-native";
          path = omp.nativeBuild;
        }
        {
          name = "omp-native-dependencies";
          path = omp.nativeBuild.dependencyArtifacts;
        }
      ];

      packages.publish-ci-cache = publisher;
      apps.publish-ci-cache = {
        type = "app";
        program = "${publisher}/bin/publish-ci-cache";
        meta.description = "Publish the explicit CI cache closure to Cachix";
      };
    };
}

{ ... }:
{
  aw1cks.modules.darwin.linux-builder =
    { pkgs, ... }:
    {
      nix.linux-builder = {
        enable = true;
        package = pkgs.unstable.darwin.linux-builder-vz;
        systems = [
          "aarch64-linux"
          "x86_64-linux"
        ];
        supportedFeatures = [ ];
        maxJobs = 2;

        # Upstream resets the writable disk on launchd start, not idle guest boots.
        ephemeral = true;

        config = {
          nix.settings.max-jobs = 2;
          virtualisation = {
            cores = 2;
            darwin-builder = {
              memorySize = 2 * 1024;
              diskSize = 20 * 1024;
            };
            vz = {
              idleTimeout = 120;
              # Rosetta is a host prerequisite; never install it during activation.
              rosetta.enable = true;
              nestedVirtualization = false;
            };
          };
        };
      };
    };
}

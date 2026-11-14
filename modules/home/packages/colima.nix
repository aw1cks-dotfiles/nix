{ ... }:
{
  aw1cks.modules.home.colima =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.modules.colima;
      yaml = pkgs.formats.yaml { };
    in
    {
      options.modules.colima = {
        enable = lib.mkEnableOption "Colima client tools and a template for manually managed VMs";

        mounts = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                location = lib.mkOption {
                  type = lib.types.str;
                  description = "Host directory to share with new Colima profiles. Colima expands ~ at runtime.";
                };
                writable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Allow the guest to write to this host directory.";
                };
              };
            }
          );
          default = [ ];
          description = ''
            Explicit host project mount allowlist for new profiles. An empty list
            shares no project directories, not the whole home directory. Colima's
            required internal mounts are separate. Existing profiles are unchanged.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = pkgs.stdenv.hostPlatform.isDarwin;
            message = "modules.colima requires macOS for the VZ and VirtioFS template.";
          }
        ];

        home.packages = with pkgs; [
          colima
          docker-client
          docker-compose
          docker-buildx
        ];

        # Only new profiles use this template; Colima owns each profile's mutable
        # colima.yaml and data. Activation never starts or stops a VM.
        home.file.".colima/_templates/default.yaml".source = yaml.generate "colima-default.yaml" {
          cpu = 2;
          memory = 2;
          disk = 40;
          arch = "host";
          vmType = "vz";
          mountType = "virtiofs";
          rosetta = true;
          runtime = "docker";
          kubernetes.enabled = false;
          sshConfig = true;
          # Colima interprets [] as a writable whole-home mount; null means none.
          mounts = if cfg.mounts == [ ] then null else cfg.mounts;
        };

        # Docker's conventional user plugin directory works for shell and GUI
        # callers without owning config.json, contexts, or credential entries.
        home.file.".docker/cli-plugins/docker-compose".source =
          "${pkgs.docker-compose}/libexec/docker/cli-plugins/docker-compose";
        home.file.".docker/cli-plugins/docker-buildx".source =
          "${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx";
      };
    };
}

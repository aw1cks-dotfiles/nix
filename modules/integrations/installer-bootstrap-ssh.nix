{ lib, ... }:
{
  flake.nixosModules.installer-bootstrap-ssh =
    { config, ... }:
    {
      options.aw1cks.provisioning.bootstrapAuthorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.singleLineStr;
        default = [ ];
        description = "Operator public keys authorized for temporary installer root SSH access.";
      };

      config = {
        assertions = [
          {
            assertion = config.aw1cks.provisioning.bootstrapAuthorizedKeys != [ ];
            message = "installer-bootstrap-ssh requires aw1cks.provisioning.bootstrapAuthorizedKeys to be set explicitly.";
          }
        ];

        # Installer and kexec environments need temporary root access before the
        # final host user exists. Keep that bootstrap policy separate from the
        # durable host user module.
        users.mutableUsers = false;

        services.openssh = {
          enable = true;
          openFirewall = true;
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            PermitRootLogin = lib.mkForce "prohibit-password";
          };
        };

        users.users.root.openssh.authorizedKeys.keys =
          lib.mkDefault config.aw1cks.provisioning.bootstrapAuthorizedKeys;
      };
    };
}

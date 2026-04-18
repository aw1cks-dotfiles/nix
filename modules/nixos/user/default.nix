{ lib, config, ... }:
{
  aw1cks.modules.nixos.user =
    {
      identity,
      resolvedUser,
      resolvedHomeDirectory,
      ...
    }:
    {
      imports = [ config.aw1cks.modules.nixos.user-shell-policy ];

      users.users.${resolvedUser} = {
        isNormalUser = true;
        description = identity.fullName;
        home = lib.mkDefault resolvedHomeDirectory;
        extraGroups = lib.mkDefault [ "wheel" ];
        openssh.authorizedKeys.keys = lib.mkDefault identity.authorizedKeys;
      };
    };
}

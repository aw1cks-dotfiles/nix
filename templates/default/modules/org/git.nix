{ config, lib, ... }:
{
  org.modules.home.work-git =
    { ... }:
    let
      identity = config.aw1cks.identities.work;
      gitHost = "git.${config.org.domain}";
    in
    {
      programs.git.includes = [
        {
          condition = "hasconfig:remote.*.url:git@${gitHost}:*/**";
          contents.user = {
            email = identity.email;
            name = identity.fullName;
          };
        }
      ];
    };
}

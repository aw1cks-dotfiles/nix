# Shared binary cache list — plain attrset, not a module.
# Prefixed with _ so import-tree skips it.
#
# Imported by modules/shared/nix-settings.nix (runtime daemon config) and
# modules/integrations/bootstrap-cache.nix (generated nix.conf for pre-switch
# bootstrap). Edit only this file to change the cache list.
{
  substituters = [
    "https://aw1cks-nix.cachix.org"
    "https://cache.lantian.pub/lantian" # nix-cachyos-kernel (xddxdd's Hydra CI)
    "https://cache.numtide.com"
    "https://cache.nixos-cuda.org"
    "https://niri.cachix.org"
    "https://noctalia.cachix.org"
    "https://wezterm.cachix.org"
  ];
  trustedPublicKeys = [
    "aw1cks-nix.cachix.org-1:Vv+PsqnPJFoOqNDH+neA4vSN1FHTGOL0D5TI6l06GXE="
    "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ=" # nix-cachyos-kernel
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    "wezterm.cachix.org-1:kAbhjYUC9qvblTE+s7S+kl5XM1zVa4skO+E/1IDWdH0="
  ];
}

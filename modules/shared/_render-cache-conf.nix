# No nixpkgs, flake evaluation, derivations, or network access: usable before
# any repo application (or just) has been realised. Keep this file standalone.
{
  mode ? "extra",
  caches ? import ./_cache-list.nix,
}:
let
  inherit (builtins)
    all
    concatStringsSep
    elem
    hashString
    isList
    isString
    match
    toJSON
    ;

  validList = pattern: xs: isList xs && all (x: isString x && match pattern x != null) xs;
  validCaches =
    validList "https://[A-Za-z0-9./_?=&%:+~-]+" caches.substituters
    && validList "[A-Za-z0-9._-]+:[A-Za-z0-9+/]{43}=" caches.trustedPublicKeys;

  # Recovery replaces the *whole* list; retain the official URL AND its key.
  # Source: Lix manual, nix.conf defaults (trusted-public-keys / substituters).
  official = {
    substituters = [ "https://cache.nixos.org/" ];
    trustedPublicKeys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
  };
  selected =
    if mode == "official" then
      official
    else if mode == "replace" then
      {
        substituters = official.substituters ++ caches.substituters;
        trustedPublicKeys = official.trustedPublicKeys ++ caches.trustedPublicKeys;
      }
    else
      caches;
  prefix = if mode == "extra" then "extra-" else "";
in
assert elem mode [
  "extra"
  "replace"
  "official"
];
assert validCaches;
''
  # Managed by aw1cks cache bootstrap v1
  # Inventory sha256: ${hashString "sha256" (toJSON selected)}
  ${prefix}substituters = ${concatStringsSep " " selected.substituters}
  ${prefix}trusted-public-keys = ${concatStringsSep " " selected.trustedPublicKeys}
''

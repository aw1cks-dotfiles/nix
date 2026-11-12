{
  pkgs,
  schemaPackage,
  schemaAssociations,
}:
let
  schemaURI = "file://${builtins.unsafeDiscardStringContext (toString schemaPackage)}/bundle.json";
in
{
  enabled = true;
  path = "${pkgs.yaml-language-server}/bin/yaml-language-server";
  config = {
    format.enable = true;
    validate = true;
    hover = true;
    completion = true;
    schemaStore.enable = true;
    kubernetesCRDStore.enable = false;
    customTags = [
      "!reference sequence"
      "!unsafe scalar"
    ];
    # Replace helm-ls's default remote Kubernetes alias with the pinned bundle.
    # Values files retain helm-ls's separate, chart-aware schema provider.
    schemas = schemaAssociations // {
      ${schemaURI} = (schemaAssociations.${schemaURI} or [ ]) ++ [ "templates/**" ];
    };
  };
}

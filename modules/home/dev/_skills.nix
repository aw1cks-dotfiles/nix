{
  inputs,
  lib,
  pkgs,
}:
let
  lowlevelCategories = [
    "allocators"
    "async-io"
    "binaries"
    "build-systems"
    "compiler-internals"
    "compilers"
    "computer-architecture"
    "debuggers"
    "kernel-dev"
    "kernel"
    "low-level-programming"
    "observability"
    "profilers"
    "runtimes"
    "rust"
    "security"
    "virtualization"
  ];
  buildSystems = [
    "build-acceleration"
    "cmake"
    "make"
    "ninja"
    "static-analysis"
  ];
  patches = {
    cpp-coroutines = ./files/agents/patches/cpp-coroutines.patch;
    io-uring = ./files/agents/patches/io-uring.patch;
    kernel-debugging = ./files/agents/patches/kernel-debugging.patch;
  };
  validId = id: builtins.match "[a-z0-9][a-z0-9_-]*/[a-z0-9][a-z0-9._-]*" id != null;
  checkedId =
    id:
    if validId id then
      id
    else
      throw "Invalid agent skill ID '${id}'; expected namespace/name with safe path components.";
  basename = id: lib.last (lib.splitString "/" id);
  directories =
    root: builtins.attrNames (lib.filterAttrs (_: kind: kind == "directory") (builtins.readDir root));
  notices =
    root:
    lib.mapAttrs (name: _: root + "/${name}") (
      lib.filterAttrs (
        name: kind:
        kind == "regular"
        && builtins.match "(license|licence|copying|copyright|notice)([._-].*)?" (lib.toLower name) != null
      ) (builtins.readDir root)
    );
  discover =
    namespace: license: root:
    if builtins.pathExists (root + "/SKILL.md") then
      # IDs are metadata; source retains the input's store dependency context.
      let
        name = builtins.unsafeDiscardStringContext (builtins.baseNameOf root);
      in
      [
        {
          name = checkedId "${namespace}/${name}";
          value = {
            source = root;
            inherit license;
            patches = lib.optional (namespace == "lowlevel" && builtins.hasAttr name patches) patches.${name};
          };
        }
      ]
    else
      lib.concatMap (name: discover namespace license (root + "/${name}")) (directories root);
  intelRoot = inputs.intel-performance-skills.outPath or inputs.intel-performance-skills;
  lowlevelRoot = inputs.low-level-dev-skills.outPath or inputs.low-level-dev-skills;
  lowlevelSkills = lowlevelRoot + "/skills";
  lowlevelEntries = lib.concatMap (
    category:
    lib.concatMap (
      name:
      lib.optionals (
        (category != "build-systems" || builtins.elem name buildSystems)
        && (category != "profilers" || name != "linux-perf")
      ) (discover "lowlevel" (notices lowlevelRoot) (lowlevelSkills + "/${category}/${name}"))
    ) (directories (lowlevelSkills + "/${category}"))
  ) (lib.filter (category: builtins.pathExists (lowlevelSkills + "/${category}")) lowlevelCategories);
  entries =
    discover "builtin" null ./files/agents/skills
    ++ discover "intel" (notices intelRoot) (intelRoot + "/skills")
    ++ lowlevelEntries;
  catalog = builtins.foldl' (
    acc: entry:
    if builtins.hasAttr entry.name acc then
      throw "Duplicate bundled agent skill ID '${entry.name}'."
    else
      acc // { ${entry.name} = entry.value; }
  ) { } entries;
  selectorPattern =
    selector:
    let
      parts = lib.splitString "/" selector;
      validPart =
        part:
        builtins.match "[a-z0-9*][a-z0-9._*-]*" part != null
        && builtins.length (lib.splitString "*" part) <= 2;
    in
    if builtins.length parts != 2 || !lib.all validPart parts then
      throw "Invalid agent skill selector '${selector}'; expected namespace/name with at most one '*' per component."
    else
      lib.concatMapStringsSep "/" (
        part: lib.concatMapStringsSep "[^/]*" lib.escapeRegex (lib.splitString "*" part)
      ) parts;
  resolve =
    {
      select ? [ ],
      extra ? { },
    }:
    let
      additions = lib.mapAttrs' (
        id: source:
        lib.nameValuePair (checkedId id) {
          inherit source;
          patches = [ ];
          license = null;
        }
      ) extra;
      available = catalog // additions;
      ids = builtins.attrNames available;
      selectors = map (
        text:
        let
          exclude = lib.hasPrefix "-" text;
          selector = if exclude then lib.removePrefix "-" text else text;
          pattern = selectorPattern selector;
          matches = lib.filter (id: builtins.match pattern id != null) ids;
        in
        if matches != [ ] then
          { inherit exclude matches; }
        else if exclude then
          lib.warn "Agent skill exclusion '${text}' matched no known IDs." { inherit exclude matches; }
        else
          throw "Unknown agent skill selector '${text}'; matched no known IDs."
      ) select;
      included = lib.unique (
        builtins.attrNames additions ++ lib.concatMap (s: if s.exclude then [ ] else s.matches) selectors
      );
      excluded = lib.concatMap (s: if s.exclude then s.matches else [ ]) selectors;
      selected = lib.filter (id: !builtins.elem id excluded) included;
      byBasename = lib.groupBy basename selected;
      collisions = lib.filterAttrs (_: names: builtins.length names > 1) byBasename;
    in
    builtins.seq catalog (
      if collisions != { } then
        throw (
          "Selected agent skills have duplicate installed basenames: "
          + lib.concatStringsSep "; " (
            lib.mapAttrsToList (name: names: "${name}: ${lib.concatStringsSep ", " names}") collisions
          )
        )
      else
        lib.genAttrs selected (id: available.${id})
    );
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  validator = pkgs.writeText "validate-agent-skill.py" ''
    import sys
    from pathlib import Path

    import yaml

    # Only parse the delimited YAML header, never the Markdown body.
    def validate(directory: Path) -> None:
        skill = directory / "SKILL.md"
        lines = skill.read_text(encoding="utf-8").splitlines()
        if not lines or lines[0] != "---":
            raise ValueError(f"{skill}: missing YAML frontmatter")
        try:
            end = lines.index("---", 1)
        except ValueError as error:
            raise ValueError(f"{skill}: unclosed YAML frontmatter") from error
        metadata = yaml.safe_load("\n".join(lines[1:end]))
        if not isinstance(metadata, dict):
            raise ValueError(f"{skill}: frontmatter must be a mapping")
        if metadata.get("name") != directory.name:
            raise ValueError(
                f"{skill}: frontmatter name {metadata.get('name')!r} "
                f"must equal installed basename {directory.name!r}"
            )

    try:
        validate(Path(sys.argv[1]))
    except (OSError, ValueError, yaml.YAMLError) as error:
        sys.exit(str(error))
  '';
  build =
    args:
    let
      selected = resolve args;
    in
    pkgs.runCommand "agent-skills" { } (
      ''
        mkdir -p "$out"
      ''
      + lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          id: descriptor:
          let
            name = basename id;
            target = ''"$out/${name}"'';
          in
          ''
            mkdir -p ${target}
            cp -a ${lib.escapeShellArg "${descriptor.source}"}/. ${target}/
            chmod -R u+w ${target}
            ${lib.concatMapStringsSep "\n" (patch: ''
              (cd ${target} && ${pkgs.patch}/bin/patch --batch --forward -p1 --fuzz=0 < ${lib.escapeShellArg "${patch}"})
            '') (descriptor.patches or [ ])}
            ${lib.optionalString ((descriptor.license or null) != null) ''
              mkdir -p ${target}/.upstream-license
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (notice: source: ''
                  cp ${lib.escapeShellArg "${source}"} ${target}/.upstream-license/${lib.escapeShellArg notice}
                '') descriptor.license
              )}
            ''}
            ${python}/bin/python ${validator} ${target}
          ''
        ) selected
      )
    );
in
{
  inherit catalog resolve build;
}

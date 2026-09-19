"""Build a local, GVK-discriminated schema bundle for YAML LS and kubeconform."""

import copy
import json
import re
import sys
from pathlib import Path

import yaml
from jsonschema import Draft7Validator

DRAFT = "http://json-schema.org/draft-07/schema#"
METADATA = "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta"


def pointer(value):
    return value.replace("~", "~0").replace("/", "~1")


def portable_pattern(pattern):
    """Translate RE2 case-insensitive literal groups used by Prometheus CRDs.

    JSON Schema consumers use ECMAScript/Python regexes, which reject Go's
    unscoped (?i) inside groups. Expand ASCII literals without widening scope.
    Fail on unsupported case-folded classes rather than weakening validation.
    """
    flags = re.findall(r"\(\?[A-Za-z-]+[):]", pattern)
    if any(flag not in ("(?i)", "(?-i)") for flag in flags):
        raise ValueError(f"Unsupported regex flag group: {pattern}")
    if "(?i)" not in pattern and "(?-i)" not in pattern:
        return pattern
    result, scopes = [], []
    insensitive = in_class = False
    index = 0
    while index < len(pattern):
        char = pattern[index]
        if char == "\\":
            escaped = pattern[index + 1 : index + 2]
            if insensitive and (
                escaped.isdigit() or (escaped.isalpha() and escaped not in "dDsSwWbB")
            ):
                raise ValueError(f"Unsupported case-insensitive escape: {pattern}")
            result.append(pattern[index : index + 2])
            index += 2
            continue
        flag = next(
            (flag for flag in ("(?i)", "(?-i)") if pattern.startswith(flag, index)),
            None,
        )
        if flag and not in_class:
            insensitive = flag == "(?i)"
            index += len(flag)
            continue
        if char == "[":
            in_class = True
        elif char == "]":
            in_class = False
        elif not in_class and char == "(":
            scopes.append(insensitive)
        elif not in_class and char == ")":
            insensitive = scopes.pop()
        if insensitive and not char.isascii() and char.isalpha():
            raise ValueError(f"Unsupported non-ASCII case folding: {pattern}")
        if insensitive and char.isascii() and char.isalpha():
            if in_class:
                raise ValueError(
                    f"Unsupported case-insensitive character class: {pattern}"
                )
            result.append(f"[{char.lower()}{char.upper()}]")
        else:
            result.append(char)
        index += 1
    return "".join(result)


def normalize(schema, root, close_objects=True):
    """Translate structural-schema types; keep private references inside the bundle."""
    if not isinstance(schema, dict):
        return schema
    schema = copy.deepcopy(schema)
    schema.pop("$id", None)
    schema.pop("id", None)
    ref = schema.get("$ref")
    if isinstance(ref, str):
        if not ref.startswith("#"):
            raise ValueError(f"External schema reference is not allowed: {ref}")
        schema["$ref"] = root + ref[1:]

    for key in ("properties", "patternProperties", "definitions", "$defs"):
        if key in schema:
            schema[key] = {
                name: normalize(child, root) for name, child in schema[key].items()
            }
    for key in (
        "items",
        "additionalProperties",
        "additionalItems",
        "not",
        "if",
        "then",
        "else",
        "contains",
    ):
        if key in schema:
            child = schema[key]
            structural = key not in ("not", "if", "then", "else")
            schema[key] = (
                [normalize(item, root, structural) for item in child]
                if isinstance(child, list)
                else normalize(child, root, structural)
            )
    for key in ("allOf", "anyOf", "oneOf"):
        if key in schema:
            schema[key] = [normalize(child, root, False) for child in schema[key]]

    if (
        schema.get("x-kubernetes-int-or-string")
        and "type" not in schema
        and "anyOf" not in schema
    ):
        schema["anyOf"] = [{"type": "integer"}, {"type": "string"}]
    if schema.pop("nullable", False):
        if isinstance(schema.get("type"), str):
            schema["type"] = [schema["type"], "null"]
        elif "anyOf" in schema:
            schema["anyOf"].append({"type": "null"})
    if schema.get("x-kubernetes-preserve-unknown-fields"):
        schema.setdefault("additionalProperties", True)
    elif (
        close_objects
        and "object"
        in (
            [schema.get("type")]
            if isinstance(schema.get("type"), str)
            else schema.get("type", [])
        )
        and "properties" in schema
    ):
        schema.setdefault("additionalProperties", False)
    if isinstance(schema.get("pattern"), str):
        schema["pattern"] = portable_pattern(schema["pattern"])
    return schema


def identity(group, version, kind):
    if group and not re.fullmatch(
        r"[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)*", group
    ):
        raise ValueError(f"Invalid API group: {group}")
    if not re.fullmatch(r"v[0-9]+(?:(?:alpha|beta)[0-9]+)?", version):
        raise ValueError(f"Invalid API version: {version}")
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9]*", kind):
        raise ValueError(f"Invalid resource kind: {kind}")
    return group, version, kind


def read_crds(path):
    for document in yaml.safe_load_all(Path(path).read_text()):
        if document is None:
            continue
        documents = (
            document.get("items", []) if document.get("kind") == "List" else [document]
        )
        for crd in documents:
            if (
                crd.get("kind") != "CustomResourceDefinition"
                or crd.get("apiVersion") != "apiextensions.k8s.io/v1"
            ):
                raise ValueError(f"Expected an apiextensions.k8s.io/v1 CRD in {path}")
            spec = crd["spec"]
            if not spec["group"]:
                raise ValueError(
                    f"A downstream CRD must have a nonempty API group: {path}"
                )
            served = [v for v in spec["versions"] if v.get("served", False)]
            if not served:
                raise ValueError(
                    f"CRD has no served versions: {crd.get('metadata', {}).get('name')}"
                )
            for version in served:
                key = identity(spec["group"], version["name"], spec["names"]["kind"])
                yield key, version["schema"]["openAPIV3Schema"]


def build(manifest, output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    definitions = json.loads(Path(manifest["definitions"]).read_text())["definitions"]
    resources = {
        ("", "v1", "List"): (
            {
                "type": "object",
                "properties": {
                    "metadata": {
                        "$ref": "#/definitions/io.k8s.apimachinery.pkg.apis.meta.v1.ListMeta"
                    },
                    "items": {"type": "array", "items": {"$ref": "#"}},
                },
                "required": ["items"],
                "additionalProperties": False,
            },
            "kubernetes",
            False,
        ),
    }
    for name, schema in list(definitions.items()):
        for gvk in schema.get("x-kubernetes-group-version-kind", []):
            key = identity(gvk["group"], gvk["version"], gvk["kind"])
            resources[key] = (schema, "kubernetes", False)

    for entry in manifest["schemas"]:
        key = identity(entry["group"], entry["version"], entry["kind"])
        if key in resources:
            raise ValueError(f"Duplicate public schema: {key}")
        resources[key] = (
            json.loads(Path(entry["path"]).read_text()),
            entry["source"],
            True,
        )

    extra_keys = set()
    for path in manifest["extraCRDs"]:
        for key, schema in read_crds(path):
            if key in extra_keys:
                raise ValueError(f"Duplicate downstream CRD group/version/kind: {key}")
            extra_keys.add(key)
            # Deliberate override: downstream CRDs describe the installed operator release.
            resources[key] = (schema, "downstream:" + Path(path).name, True)

    branches, inventory, filenames = [], [], set()
    for (group, version, kind), (source, origin, custom) in sorted(resources.items()):
        # kubeconform reports Group=v1 for the core apiVersion=v1, not an empty group.
        directory_name = group or version
        filename = (directory_name, version, kind.lower())
        if filename in filenames:
            raise ValueError(f"Case-folded kubeconform filename collision: {filename}")
        filenames.add(filename)
        api_version = f"{group}/{version}" if group else version
        name = f"resource:{api_version}:{kind}"
        ref = "#/definitions/" + pointer(name)
        source = copy.deepcopy(source)
        metadata = (
            source.get("properties", {}).pop("metadata", None) if custom else None
        )
        schema = normalize(source, ref) if custom else source
        properties = schema.setdefault("properties", {})
        properties["apiVersion"] = {"type": "string", "enum": [api_version]}
        properties["kind"] = {"type": "string", "enum": [kind]}
        if custom:
            metadata_schema = {"$ref": "#/definitions/" + METADATA}
            properties["metadata"] = (
                {"allOf": [metadata_schema, normalize(metadata, ref, False)]}
                if metadata
                else metadata_schema
            )
        schema["type"] = "object"
        schema["required"] = sorted(
            set(schema.get("required", [])) | {"apiVersion", "kind"}
        )
        definitions[name] = schema
        branches.append({"$ref": ref})

        directory = output / "kubeconform" / directory_name
        directory.mkdir(parents=True, exist_ok=True)
        relative = "../../bundle.json"
        (directory / f"{kind.lower()}_{version}.json").write_text(
            json.dumps({"$schema": DRAFT, "$ref": relative + ref}) + "\n"
        )
        inventory.append({"apiVersion": api_version, "kind": kind, "source": origin})

    bundle = {"$schema": DRAFT, "definitions": definitions, "oneOf": branches}
    Draft7Validator.check_schema(bundle)
    (output / "bundle.json").write_text(
        json.dumps(bundle, separators=(",", ":")) + "\n"
    )
    (output / "inventory.json").write_text(
        json.dumps(
            {
                "kubernetesVersion": manifest["kubernetesVersion"],
                "catalogRevision": manifest["catalogRevision"],
                "resources": inventory,
            },
            indent=2,
        )
        + "\n"
    )
    print(
        f"Built {len(resources)} GVK schemas ({len(extra_keys)} downstream overrides/additions)"
    )


if __name__ == "__main__":
    build(json.loads(Path(sys.argv[1]).read_text()), sys.argv[2])

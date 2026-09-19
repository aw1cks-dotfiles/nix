"""Offline regression tests for the downstream CRD contract and schema isolation."""

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

import yaml
from jsonschema import Draft7Validator

source = os.environ.get("SCHEMA_BUILDER", str(Path(__file__).with_name("build.py")))
spec = importlib.util.spec_from_file_location("schema_builder", source)
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class SchemaTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        definitions = {
            builder.METADATA: {
                "type": "object",
                "properties": {"name": {"type": "string"}},
            },
            "io.k8s.apimachinery.pkg.apis.meta.v1.ListMeta": {"type": "object"},
            "ConfigMap": {
                "type": "object",
                "properties": {
                    "data": {
                        "type": "object",
                        "additionalProperties": {"type": "string"},
                    }
                },
                "x-kubernetes-group-version-kind": [
                    {"group": "", "version": "v1", "kind": "ConfigMap"}
                ],
            },
        }
        self.definitions = self.root / "definitions.json"
        self.definitions.write_text(json.dumps({"definitions": definitions}))
        self.manifest = {
            "definitions": str(self.definitions),
            "schemas": [],
            "extraCRDs": [],
            "kubernetesVersion": "1.36.0",
            "catalogRevision": "test",
        }

    def crd(self):
        return {
            "apiVersion": "apiextensions.k8s.io/v1",
            "kind": "CustomResourceDefinition",
            "metadata": {"name": "widgets.platform.example.test"},
            "spec": {
                "group": "platform.example.test",
                "names": {"kind": "Widget", "plural": "widgets"},
                "scope": "Namespaced",
                "versions": [
                    {
                        "name": "v1",
                        "served": True,
                        "storage": True,
                        "schema": {
                            "openAPIV3Schema": {
                                "type": "object",
                                "required": ["spec"],
                                "properties": {
                                    "spec": {
                                        "type": "object",
                                        "required": ["replicas"],
                                        "properties": {"replicas": {"type": "integer"}},
                                    }
                                },
                            }
                        },
                    }
                ],
            },
        }

    def add(self, crd, name="custom.yaml"):
        path = self.root / name
        path.write_text(yaml.safe_dump(crd))
        self.manifest["extraCRDs"].append(str(path))
        return path

    def compile(self):
        output = self.root / "output"
        builder.build(self.manifest, output)
        self.bundle = json.loads((output / "bundle.json").read_text())
        return Draft7Validator(self.bundle)

    def widget(self, spec=None):
        return {
            "apiVersion": "platform.example.test/v1",
            "kind": "Widget",
            "metadata": {"name": "test"},
            "spec": spec or {"replicas": 2},
        }

    def test_downstream_and_core_share_bundle(self):
        self.add(self.crd())
        validator = self.compile()
        self.assertTrue(validator.is_valid(self.widget()))
        self.assertFalse(validator.is_valid(self.widget({"replicas": "wrong"})))
        self.assertFalse(validator.is_valid(self.widget({"replicas": 1, "typo": True})))
        self.assertTrue(
            validator.is_valid(
                {"apiVersion": "v1", "kind": "ConfigMap", "data": {"key": "value"}}
            )
        )
        self.assertFalse(
            validator.is_valid({"apiVersion": "unknown.example/v1", "kind": "Widget"})
        )
        path = self.root / "output/kubeconform/platform.example.test/widget_v1.json"
        self.assertTrue(path.is_file())
        self.assertTrue(
            json.loads(path.read_text())["$ref"].startswith("../../bundle.json#")
        )
        core = self.root / "output/kubeconform/v1/configmap_v1.json"
        self.assertTrue(core.is_file())
        self.assertTrue(
            json.loads(core.read_text())["$ref"].startswith("../../bundle.json#")
        )

    def test_served_versions_and_multi_document_lists(self):
        crd = self.crd()
        old = json.loads(json.dumps(crd["spec"]["versions"][0]))
        old.update(name="v1alpha1", served=False)
        beta = json.loads(json.dumps(old))
        beta.update(name="v1beta1", served=True)
        crd["spec"]["versions"] += [old, beta]
        path = self.add({"apiVersion": "v1", "kind": "List", "items": [crd]})
        path.write_text("---\n" + path.read_text() + "---\n")
        self.compile()
        paths = self.root / "output/kubeconform/platform.example.test"
        self.assertTrue((paths / "widget_v1beta1.json").exists())
        self.assertFalse((paths / "widget_v1alpha1.json").exists())

    def test_downstream_overrides_public_but_duplicate_extras_fail(self):
        public = self.root / "public.json"
        public.write_text(json.dumps({"type": "object", "required": ["oldField"]}))
        self.manifest["schemas"] = [
            {
                "group": "platform.example.test",
                "version": "v1",
                "kind": "Widget",
                "path": str(public),
                "source": "pinned-public",
            }
        ]
        self.add(self.crd())
        self.assertTrue(self.compile().is_valid(self.widget()))
        self.add(self.crd(), "duplicate.yaml")
        with self.assertRaisesRegex(ValueError, "Duplicate downstream"):
            self.compile()

    def test_structural_schema_nullable_int_or_string_and_preservation(self):
        crd = self.crd()
        crd["spec"]["versions"][0]["schema"]["openAPIV3Schema"]["properties"][
            "spec"
        ] = {
            "type": "object",
            "properties": {
                "replicas": {"type": "integer", "nullable": True},
                "port": {"x-kubernetes-int-or-string": True},
                "opaque": {
                    "type": "object",
                    "x-kubernetes-preserve-unknown-fields": True,
                },
            },
        }
        self.add(crd)
        validator = self.compile()
        self.assertTrue(
            validator.is_valid(
                self.widget({"replicas": None, "port": "http", "opaque": {"custom": 1}})
            )
        )
        self.assertTrue(validator.is_valid(self.widget({"port": 8080})))
        self.assertFalse(validator.is_valid(self.widget({"port": True})))

    def test_local_refs_are_namespaced(self):
        crd = self.crd()
        schema = crd["spec"]["versions"][0]["schema"]["openAPIV3Schema"]
        schema["definitions"] = {"count": {"type": "integer"}}
        schema["properties"]["spec"]["properties"]["replicas"] = {
            "$ref": "#/definitions/count"
        }
        self.add(crd)
        validator = self.compile()
        self.assertTrue(validator.is_valid(self.widget()))
        self.assertFalse(validator.is_valid(self.widget({"replicas": "wrong"})))

    def test_external_refs_rejected(self):
        crd = self.crd()
        crd["spec"]["versions"][0]["schema"]["openAPIV3Schema"]["properties"][
            "spec"
        ] = {
            "$ref": "https://private.example.test/schema.json",
        }
        self.add(crd)
        with self.assertRaisesRegex(ValueError, "External schema reference"):
            self.compile()

    def test_partial_compositions_do_not_close_the_parent_object(self):
        crd = self.crd()
        crd["spec"]["versions"][0]["schema"]["openAPIV3Schema"]["properties"][
            "spec"
        ] = {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "value": {"type": "string"},
                "valueFrom": {"type": "object"},
            },
            "oneOf": [
                {"properties": {"value": {}}, "required": ["value"]},
                {"properties": {"valueFrom": {}}, "required": ["valueFrom"]},
            ],
        }
        self.add(crd)
        validator = self.compile()
        self.assertTrue(
            validator.is_valid(self.widget({"name": "FOO", "value": "bar"}))
        )
        self.assertFalse(
            validator.is_valid(
                self.widget({"name": "FOO", "value": "bar", "valueFrom": {}})
            )
        )

    def test_metadata_constraints_and_typed_preserved_maps(self):
        crd = self.crd()
        schema = crd["spec"]["versions"][0]["schema"]["openAPIV3Schema"]
        schema["properties"]["metadata"] = {
            "type": "object",
            "properties": {"name": {"pattern": "^allowed-"}},
        }
        schema["properties"]["spec"] = {
            "type": "object",
            "x-kubernetes-preserve-unknown-fields": True,
            "additionalProperties": {"type": "string"},
        }
        self.add(crd)
        validator = self.compile()
        resource = self.widget({"arbitrary": "string"})
        self.assertFalse(validator.is_valid(resource))
        resource["metadata"] = {"name": "allowed-name", "namespace": "default"}
        self.assertTrue(validator.is_valid(resource))
        resource["spec"]["arbitrary"] = 2
        self.assertFalse(validator.is_valid(resource))

    def test_resource_lists_validate_core_custom_and_unknown_items(self):
        self.add(self.crd())
        validator = self.compile()
        resource = {
            "apiVersion": "v1",
            "kind": "List",
            "items": [
                self.widget(),
                {"apiVersion": "v1", "kind": "ConfigMap", "data": {"key": "value"}},
            ],
        }
        self.assertTrue(validator.is_valid(resource))
        resource["items"].append(
            {"apiVersion": "unknown.example/v1", "kind": "Unknown"}
        )
        self.assertFalse(validator.is_valid(resource))

    def test_case_folded_filenames_fail_instead_of_overwriting(self):
        self.add(self.crd())
        crd = self.crd()
        crd["spec"]["names"]["kind"] = "WIDGET"
        self.add(crd, "different-case.yaml")
        with self.assertRaisesRegex(ValueError, "filename collision"):
            self.compile()

    def test_re2_literal_case_folding_preserves_group_scope(self):
        import re

        pattern = builder.portable_pattern("^((?i)jan|feb)end$")
        self.assertIsNotNone(re.fullmatch(pattern, "JANend"))
        self.assertIsNone(re.fullmatch(pattern, "janEND"))
        self.assertIsNone(re.fullmatch(pattern, "MARCHend"))
        with self.assertRaisesRegex(ValueError, "character class"):
            builder.portable_pattern("(?i)[a-z]")
        for pattern in (r"(?i)^\x61$", r"(?i)^\141$", "(?i)é", "(?i:foo)", "(?im)foo"):
            with self.assertRaises(ValueError):
                builder.portable_pattern(pattern)

    def test_nullable_objects_still_reject_unknown_fields(self):
        schema = builder.normalize(
            {
                "type": "object",
                "nullable": True,
                "properties": {"known": {"type": "string"}},
            },
            "#",
        )
        validator = Draft7Validator(schema)
        self.assertTrue(validator.is_valid(None))
        self.assertTrue(validator.is_valid({"known": "ok"}))
        self.assertFalse(validator.is_valid({"typo": "oops"}))

    def test_non_crds_and_unsafe_groups_rejected(self):
        self.add({"apiVersion": "v1", "kind": "Secret"})
        with self.assertRaisesRegex(ValueError, "Expected.*CRD"):
            self.compile()
        for group in ("..", "../outside", "bad/group", "bad..group"):
            with self.assertRaises(ValueError):
                builder.identity(group, "v1", "Widget")


if __name__ == "__main__":
    unittest.main()

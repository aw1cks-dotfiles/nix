"""Offline regression tests for the downstream CRD contract and schema isolation."""

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

import yaml
from jsonschema import Draft7Validator
from referencing import Registry, Resource

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

    def detection_validator(self):
        self.compile()
        schema = json.loads((self.root / "output/detected.json").read_text())
        schema["$id"] = "https://schemas.example.test/kubernetes/detected.json"
        registry = Registry().with_resource(
            "https://schemas.example.test/kubernetes/bundle.json",
            Resource.from_contents(self.bundle),
        )
        return Draft7Validator(schema, registry=registry)

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
        self.assertTrue(
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

    def test_detection_validates_known_gvks_without_a_filename_association(self):
        self.add(self.crd())
        validator = self.detection_validator()
        self.assertTrue(validator.is_valid(self.widget()))
        self.assertFalse(validator.is_valid(self.widget({"replicas": "wrong"})))
        self.assertFalse(
            validator.is_valid(
                {"apiVersion": "v1", "kind": "ConfigMap", "data": {"key": 42}}
            )
        )

    def test_detection_leaves_unrelated_partial_and_unknown_documents_alone(self):
        self.add(self.crd())
        validator = self.detection_validator()
        for document in [
            None,
            "plain YAML",
            [{"hosts": "all", "tasks": []}],
            {"stages": ["test"], "check": {"script": "echo hello"}},
            {"jobs": {"nested": self.widget({"replicas": "not a root resource"})}},
            {"kind": "Widget"},
            {"apiVersion": "platform.example.test/v1"},
            {"apiVersion": "unknown.example/v1", "kind": "Widget", "spec": {}},
            {"apiVersion": "v1", "kind": "Config", "clusters": []},
        ]:
            with self.subTest(document=document):
                self.assertTrue(validator.is_valid(document))

    def test_unknown_gvks_do_not_inherit_known_resource_constraints(self):
        self.add(self.crd())
        validator = self.compile()
        for api_version, kind in [
            ("unknown.example/v1", "Widget"),
            ("platform.example.test/v2", "Widget"),
            ("platform.example.test/v1", "Unknown"),
            ("v1", "Unknown"),
        ]:
            with self.subTest(apiVersion=api_version, kind=kind):
                self.assertTrue(
                    validator.is_valid({"apiVersion": api_version, "kind": kind})
                )
                self.assertTrue(
                    validator.is_valid(
                        {
                            "apiVersion": api_version,
                            "kind": kind,
                            "spec": {"replicas": "not an integer", "typo": True},
                            "data": {"key": 42},
                            "unrelated": True,
                        }
                    )
                )

    def test_known_gvks_reject_resource_specific_invalid_fields(self):
        self.add(self.crd())
        validator = self.compile()
        for resource, path, keyword in [
            (self.widget({"replicas": "wrong"}), ["spec", "replicas"], "type"),
            (
                self.widget({"replicas": 1, "typo": True}),
                ["spec"],
                "additionalProperties",
            ),
            (
                {"apiVersion": "v1", "kind": "ConfigMap", "data": {"key": 42}},
                ["data", "key"],
                "type",
            ),
        ]:
            with self.subTest(resource=resource):
                errors = list(validator.iter_errors(resource))
                self.assertEqual(len(errors), 1)
                self.assertEqual(list(errors[0].path), path)
                self.assertEqual(errors[0].validator, keyword)

    def test_partial_discriminators_only_report_root_requirements(self):
        self.add(self.crd())
        validator = self.compile()
        for discriminators in [
            {},
            {"apiVersion": "v1"},
            {"apiVersion": "platform.example.test/v1"},
            {"kind": "Widget"},
            {"kind": "List"},
        ]:
            with self.subTest(discriminators=discriminators):
                resource = {
                    **discriminators,
                    "spec": {"replicas": "wrong", "typo": True},
                    "data": {"key": 42},
                }
                errors = list(validator.iter_errors(resource))
                self.assertEqual(len(errors), 2 - len(discriminators))
                for error in errors:
                    self.assertEqual(error.validator, "required")
                    self.assertEqual(list(error.path), [])
                    self.assertEqual(list(error.schema_path), ["required"])

    def test_root_requires_an_object_and_string_discriminators(self):
        validator = self.compile()
        for resource in [None, [], "ConfigMap"]:
            with self.subTest(resource=resource):
                self.assertFalse(validator.is_valid(resource))
        for api_version, kind in [(1, "ConfigMap"), ("v1", None)]:
            with self.subTest(apiVersion=api_version, kind=kind):
                errors = list(
                    validator.iter_errors({"apiVersion": api_version, "kind": kind})
                )
                self.assertEqual(len(errors), 1)
                self.assertEqual(errors[0].validator, "type")

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
            {
                "apiVersion": "unknown.example/v1",
                "kind": "Unknown",
                "spec": {"replicas": "unvalidated"},
            }
        )
        self.assertTrue(validator.is_valid(resource))
        resource["items"][0]["spec"]["replicas"] = "wrong"
        self.assertFalse(validator.is_valid(resource))
        resource["items"][0]["spec"]["replicas"] = 2
        resource["items"][-1].pop("kind")
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

"""Combine the pinned light/dark HN userstyles for Firefox's user cascade."""

import sys
from pathlib import Path

import tinycss2


def user_important(nodes):
    for node in nodes:
        if node.type == "error":
            raise ValueError(f"CSS parse error at {node.source_line}:{node.source_column}: {node.message}")
        if node.type == "declaration":
            # Normal user rules lose to author CSS, including HN and Dark Reader.
            node.important = True
        elif node.type in {"at-rule", "qualified-rule"} and node.content is not None:
            # Preserve @-moz-document, media queries and nested selectors.
            node.content = user_important(tinycss2.parse_blocks_contents(node.content))
    return nodes


light, dark, destination = map(Path, sys.argv[1:])
styles = []
for appearance, source in (("light", light), ("dark", dark)):
    rules = tinycss2.parse_stylesheet(source.read_text(encoding="utf-8"))
    css = tinycss2.serialize(user_important(rules))
    styles.append(f"@media (prefers-color-scheme: {appearance}) {{\n{css}\n}}\n")
destination.write_text("".join(styles), encoding="utf-8")

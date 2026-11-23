#!/usr/bin/env python3
"""Builds docs/classes/ from the ## doc comments in the project's scripts.

The pages use Godot's own converter (tools/godot/doc/tools/make_rst.py), so they read like
the class reference on docs.godotengine.org. Links to engine classes, such as Node, are
pointed at that site when the docs are built (see godot_links in _extensions).

Usage, from the project folder:

    godot --headless --doctool /tmp/engine_xml
    godot --headless --doctool /tmp/project_xml --gdscript-docs res://character_system
    python3 docs/tools/make_classref.py /tmp/engine_xml /tmp/project_xml

The first command writes the engine's class reference XML, the second the XML for every
script with a class_name. Run both with the same Godot version you use for the project.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

DOCS = Path(__file__).resolve().parent.parent
ROOT = DOCS.parent
MAKE_RST = DOCS / "tools" / "godot" / "doc" / "tools" / "make_rst.py"
OUT = DOCS / "classes"
ENGINE_DOCS = "https://docs.godotengine.org/en/stable/classes/"

# Documented private methods that are meant to be overridden. Shown as "virtual".
VIRTUALS = {
    "Component": {"_requires", "_stats", "_start", "_stop", "_on_event", "_warnings"},
    "Condition": {"_test"},
    "Effect": {"_execute"},
    "MotorNode": {"_stats", "_enter", "_exit", "_physics_update"},
    "MovementMode": {"_can_enter", "_get_next_mode"},
    "LayeredMove": {"_can_start"},
}
# Documented private methods that are internal plumbing. Left out of the reference.
HIDDEN = {
    "Component": {"_begin", "_halt"},
}
# Sections of the index, by the folder the script is in. The first match wins.
GROUPS = [
    ("Core", "character_system/core/"),
    ("Movement", "character_system/characters/motor/"),
    ("Character components", "character_system/characters/"),
    ("Item components", "character_system/items/"),
    ("World", "character_system/world/"),
    ("Effects", "character_system/resources/effects/"),
    ("Conditions", "character_system/resources/conditions/"),
    ("Amounts", "character_system/resources/amounts/"),
    ("Resources", "character_system/resources/"),
    ("Examples", "character_system/examples/"),
]


def class_paths() -> dict[str, str]:
    """class_name -> script path, relative to the project folder."""
    paths = {}
    for script in sorted(ROOT.glob("character_system/**/*.gd")):
        match = re.search(r"^class_name\s+(\w+)", script.read_text(encoding="utf-8"), re.M)
        if match:
            paths[match.group(1)] = script.relative_to(ROOT).as_posix()
    return paths


def clean_xml(src: Path, dst: Path) -> None:
    """Drops undocumented private members and marks the virtual methods."""
    tree = ET.parse(src)
    cls = tree.getroot()
    name = cls.get("name")
    for group, item in (("members", "member"), ("methods", "method"), ("signals", "signal"),
                        ("constants", "constant")):
        parent = cls.find(group)
        if parent is None:
            continue
        for element in list(parent.findall(item)):
            member = element.get("name", "")
            if not member.startswith("_"):
                continue
            description = (element.findtext("description") or element.text or "").strip()
            if not description or member in HIDDEN.get(name, set()):
                parent.remove(element)
            elif item == "method" and member in VIRTUALS.get(name, set()):
                element.set("qualifiers", "virtual")
        if len(parent) == 0:
            cls.remove(parent)
    tree.write(dst, encoding="UTF-8", xml_declaration=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("engine_xml", help="Folder from `godot --doctool`.")
    parser.add_argument("project_xml", help="Folder from `godot --doctool --gdscript-docs`.")
    args = parser.parse_args()

    paths = class_paths()
    with tempfile.TemporaryDirectory() as tmp:
        xml_dir = Path(tmp) / "xml"
        rst_dir = Path(tmp) / "rst"
        xml_dir.mkdir()
        rst_dir.mkdir()
        ours = []
        for xml in sorted(Path(args.project_xml).glob("*.xml")):
            ours.append(xml.stem)
            clean_xml(xml, xml_dir / xml.name)
        engine = [str(p) for p in Path(args.engine_xml).rglob("*.xml")
                  if p.stem not in ours]
        engine_dir = Path(tmp) / "engine"
        engine_dir.mkdir()
        for p in engine:
            shutil.copy(p, engine_dir)

        result = subprocess.run(
            [sys.executable, str(MAKE_RST), "-o", str(rst_dir), str(engine_dir), str(xml_dir)],
            capture_output=True, text=True)
        problems = [line for line in re.sub(r"\x1b\[[0-9;]*m", "", result.stdout + result.stderr)
                    .splitlines() if any(f" {c}.xml:" in line for c in ours)]
        for line in problems:
            print(line)

        if OUT.exists():
            shutil.rmtree(OUT)
        OUT.mkdir()
        files = {c: f"class_{c.lower()}.rst" for c in ours}
        texts = {c: (rst_dir / f).read_text(encoding="utf-8") for c, f in files.items()}
        for cls, text in texts.items():
            script = paths.get(cls.split(".")[0], "")
            text = re.sub(
                r"\.\. DO NOT EDIT THIS FILE!!!\n(\.\. .*\n)*",
                ".. DO NOT EDIT THIS FILE. It's generated from the ## comments in\n"
                f".. {script} by docs/tools/make_classref.py.\n", text, count=1)
            text = text.replace(
                "There is currently no description for this method. Please help us by "
                "`contributing one <https://contributing.godotengine.org/en/latest/development/"
                "documentation/class_reference.html>`__!", "No description yet.")
            text = re.sub(r"There is currently no description for this (\w+)\. Please help us "
                          r"by `contributing one <[^>]+>`__!", r"No description yet.", text)
            (OUT / files[cls]).write_text(text, encoding="utf-8")

        # The index, grouped by folder like the project. As in Godot's docs, each group is a
        # top-level heading, so the sidebar lists the groups directly under "Class reference".
        lines = [
            ":github_url: hide", ":allow_comments: False", "",
            ".. DO NOT EDIT THIS FILE. It's generated by docs/tools/make_classref.py.", "",
            ".. _doc_class_reference:", "",
            "All classes", "===========", "",
            "Every class in the system, generated from the ``##`` comments in its script. "
            "Links to Godot's own classes go to the "
            f"`Godot class reference <{ENGINE_DOCS}index.html>`__.", "",
        ]
        for title, folder in GROUPS:
            members = [c for c in ours if paths.get(c.split(".")[0], "").startswith(folder)
                       and not any(paths.get(c.split(".")[0], "").startswith(f)
                                   for _, f in GROUPS[:GROUPS.index((title, folder))])]
            if not members:
                continue
            lines += [title, "=" * len(title), "", ".. toctree::", "    :maxdepth: 1",
                      f"    :name: toc-class-ref-{title.lower().replace(' ', '-')}", ""]
            lines += [f"    {files[c][:-4]}" for c in members]
            lines.append("")
        (OUT / "index.rst").write_text("\n".join(lines), encoding="utf-8")
        print(f"Wrote {len(ours)} classes to {OUT.relative_to(ROOT)}.")
        if problems:
            print(f"{len(problems)} notes from Godot's doc checker, listed above.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

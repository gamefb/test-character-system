"""Points references to Godot's own classes at the Godot class reference.

The generated class pages link types the way Godot's docs do, e.g.
:ref:`Node<class_Node>` or :ref:`add_child()<class_Node_method_add_child>`. This project only
has pages for its own classes, so any such label that isn't defined here becomes a link to
docs.godotengine.org instead of a broken reference.
"""

import re

from docutils import nodes

ENGINE_DOCS = "https://docs.godotengine.org/en/stable/classes/"
LABEL = re.compile(r"(class|enum|constant)_(@?[A-Za-z0-9]+)")


def resolve(app, env, node, contnode):
    if node.get("reftype") != "ref":
        return None
    target = node.get("reftarget", "")
    match = LABEL.match(target)
    if not match:
        return None
    page = f"{ENGINE_DOCS}class_{match.group(2).lower().replace('@', '@')}.html"
    if target.lower() != f"class_{match.group(2).lower()}":
        page += "#" + target.lower().replace("_", "-").replace("@", "")
    link = nodes.reference("", "", internal=False, refuri=page, classes=["godot-engine-link"])
    link.append(contnode)
    return link


def setup(app):
    app.connect("missing-reference", resolve)
    return {"parallel_read_safe": True, "parallel_write_safe": True}

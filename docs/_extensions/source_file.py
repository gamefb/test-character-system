"""A ``source-file`` directive: a project file's code, folded under its path.

    .. source-file:: ../../character_system/core/_base/component.gd

It takes the same options as ``literalinclude`` and reads the file when the site is built, so
the listing always matches the code. Files of 30 lines or fewer start unfolded; add ``:open:``
to unfold a longer one.
"""

from docutils import nodes
from docutils.parsers.rst import directives
from sphinx.directives.code import LiteralInclude


class source_details(nodes.General, nodes.Element):
    pass


def visit_details(self, node):
    attrs = ' open=""' if node.get("open") else ""
    self.body.append(f'<details class="source-file"{attrs}><summary>')
    self.body.append(f'<code class="docutils literal notranslate">{self.encode(node["path"])}</code>')
    self.body.append(f' <span class="source-file-lines">{node["lines"]} lines</span></summary>')


def depart_details(self, node):
    self.body.append("</details>")


def skip(self, node):
    raise nodes.SkipNode


class SourceFile(LiteralInclude):
    option_spec = dict(LiteralInclude.option_spec, open=directives.flag)

    def run(self):
        self.options.setdefault("language", "gdscript")
        is_open = "open" in self.options
        self.options.pop("open", None)
        result = super().run()
        path = self.arguments[0]
        while path.startswith("../"):
            path = path[3:]
        text = "".join(n.astext() for n in result if isinstance(n, nodes.literal_block))
        lines = text.count("\n") + 1
        wrapper = source_details(path=path, lines=lines, open=is_open or lines <= 30)
        wrapper.extend(result)
        return [wrapper]


def setup(app):
    app.add_node(source_details, html=(visit_details, depart_details),
                 latex=(skip, None), text=(skip, None), man=(skip, None),
                 texinfo=(skip, None))
    app.add_directive("source-file", SourceFile)
    return {"parallel_read_safe": True, "parallel_write_safe": True}

# Sphinx configuration for the Character System documentation.
# Layout and styling follow the Godot Engine documentation (https://docs.godotengine.org),
# whose theme files and extensions are reused here; see _static/NOTICE.md.

import os
import sys

sys.path.append(os.path.abspath("_extensions"))

project = "Character System"
author = "Corey"
copyright = "2026, Corey"
version = "1.0"
release = version

extensions = [
    "gdscript",  # GDScript highlighting, from the Godot docs.
    "classref_admonitions",  # Note and warning boxes in the class reference.
    "godot_links",  # Links to Godot's own classes go to docs.godotengine.org.
    "source_file",  # Code listings read from the project, folded under their path.
    "sphinx.ext.graphviz",  # The diagrams.
    "myst_parser",  # Markdown, for RECIPES.md, which is also read inside Godot.
]

templates_path = ["_templates"]
exclude_patterns = ["_build", "tools", "README.md"]
source_suffix = {".rst": "restructuredtext", ".md": "markdown"}
myst_heading_anchors = 2
master_doc = "index"
language = "en"

pygments_style = "sphinx"
highlight_language = "gdscript"

# Code listings are pulled from the project's files, so they can't go stale.
file_insertion_enabled = True


# -- HTML output --------------------------------------------------------------

html_theme = "sphinx_rtd_theme"
html_theme_options = {
    "logo_only": True,
    "collapse_navigation": False,
    "version_selector": False,
    "language_selector": False,
    "flyout_display": "attached",
    "navigation_depth": 3,
}
html_title = "Character System documentation"
html_short_title = "Character System"
html_logo = "img/docs_logo.svg"
html_static_path = ["_static"]
html_css_files = ["css/custom.css", "css/site.css"]
html_js_files = ["js/custom.js"]
html_show_sourcelink = False
html_copy_source = False

html_context = {
    "display_github": True,
    "github_user": "gamefb",
    "github_repo": "test-character-system",
    "github_version": "main",
    "conf_py_path": "/docs/",
}

graphviz_output_format = "svg"
graphviz_dot_args = [
    "-Gbgcolor=transparent",
    "-Gfontname=Inter, sans-serif",
    "-Nfontname=Inter, sans-serif",
    "-Efontname=Inter, sans-serif",
    "-Nfontsize=11",
    "-Efontsize=10",
]

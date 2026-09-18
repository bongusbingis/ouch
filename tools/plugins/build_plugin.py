"""Wraps CourseForge.server.luau into a drop-in .rbxmx Studio plugin.

The plugin has to install into a bare design baseplate that has no Rojo project
and no repo checkout, so the shipped artifact is a single Script instance with
the whole source inlined. Run this after editing the .luau source.
"""

import pathlib
import sys

HERE = pathlib.Path(__file__).parent
SOURCE = HERE / "CourseForge.server.luau"
OUTPUT = HERE / "CourseForge.rbxmx"

TEMPLATE = """<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" \
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" \
xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
\t<Item class="Script" referent="RBX_COURSEFORGE">
\t\t<Properties>
\t\t\t<bool name="Disabled">false</bool>
\t\t\t<string name="Name">CourseForge</string>
\t\t\t<token name="RunContext">0</token>
\t\t\t<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>
\t\t</Properties>
\t</Item>
</roblox>
"""


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")

    # A CDATA section cannot contain its own terminator. Nothing in the source
    # needs one today, so treat an occurrence as a build error rather than
    # silently shipping a corrupt model file.
    if "]]>" in source:
        print("error: source contains ']]>', which cannot be embedded in CDATA", file=sys.stderr)
        return 1

    OUTPUT.write_text(TEMPLATE.format(source=source), encoding="utf-8")
    print(f"wrote {OUTPUT.name} ({OUTPUT.stat().st_size} bytes) from {len(source.splitlines())} lines")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

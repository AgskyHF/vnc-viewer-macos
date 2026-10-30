#!/usr/bin/env python3
"""Add source files to an Xcode project without opening Xcode.

The project file is a plist in the old NeXTSTEP format. New entries need:
  * a PBXBuildFile entry (one per file, per build phase)
  * a PBXFileReference entry
  * membership in the group that holds the other sources
  * membership in the Sources build phase

Identifiers are 24 hex characters, unique within the project.
"""

import re
import sys

PBXPROJ = sys.argv[1]
FILES = sys.argv[2:]  # paths relative to the group that is extended


def make_id(seed, used):
    """Deterministic 24-char hex id that does not collide with existing ones."""
    n = seed
    while True:
        candidate = "%024X" % (n & 0xFFFFFFFFFFFFFFFFFFFFFFFF)
        if candidate not in used:
            used.add(candidate)
            return candidate
        n += 1


def main():
    with open(PBXPROJ, "r", encoding="utf-8") as fh:
        text = fh.read()

    used = set(re.findall(r"\b[0-9A-F]{24}\b", text))

    # The group that holds the existing sources of the app.
    group_match = re.search(
        r"([0-9A-F]{24}) /\* Source \*/ = \{\s*isa = PBXGroup;(.*?)\n\t\t\};",
        text, re.S)
    if not group_match:
        sys.exit("Could not find the Source group in %s" % PBXPROJ)
    group_id = group_match.group(1)
    group_body = group_match.group(2)

    # The Sources build phase.
    phase_match = re.search(
        r"([0-9A-F]{24}) /\* Sources \*/ = \{\s*isa = PBXSourcesBuildPhase;(.*?)\n\t\t\};",
        text, re.S)
    if not phase_match:
        sys.exit("Could not find the Sources build phase in %s" % PBXPROJ)
    phase_id = phase_match.group(1)
    phase_body = phase_match.group(2)

    build_entries = []
    ref_entries = []
    group_children = []
    phase_files = []

    seed = 0xC0FFEE0000000000000000
    for path in FILES:
        name = path.rsplit("/", 1)[-1]
        seed += 0x1111
        file_id = make_id(seed, used)
        seed += 0x2222
        build_id = make_id(seed, used)

        ref_entries.append(
            "\t\t%s /* %s */ = {isa = PBXFileReference; fileEncoding = 4; "
            "lastKnownFileType = sourcecode.c.objc; path = %s; sourceTree = \"<group>\"; };"
            % (file_id, name, name))
        build_entries.append(
            "\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };"
            % (build_id, name, file_id, name))
        group_children.append("\t\t\t\t%s /* %s */," % (file_id, name))
        phase_files.append("\t\t\t\t%s /* %s in Sources */," % (build_id, name))

    # Insert the new PBXBuildFile entries.
    text = text.replace(
        "/* Begin PBXBuildFile section */\n",
        "/* Begin PBXBuildFile section */\n" + "\n".join(build_entries) + "\n", 1)

    # Insert the new PBXFileReference entries.
    text = text.replace(
        "/* Begin PBXFileReference section */\n",
        "/* Begin PBXFileReference section */\n" + "\n".join(ref_entries) + "\n", 1)

    # Add the files to the Source group.
    marker = "\t\t%s /* Source */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n" % group_id
    if marker not in text:
        sys.exit("Source group layout does not match expectations")
    text = text.replace(marker, marker + "\n".join(group_children) + "\n", 1)

    # Add the files to the Sources build phase.
    phase_marker = ("\t\t%s /* Sources */ = {\n\t\t\tisa = PBXSourcesBuildPhase;\n"
                    "\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n" % phase_id)
    if phase_marker not in text:
        sys.exit("Sources phase layout does not match expectations")
    text = text.replace(phase_marker, phase_marker + "\n".join(phase_files) + "\n", 1)

    with open(PBXPROJ, "w", encoding="utf-8") as fh:
        fh.write(text)

    print("Added %d file(s) to the project:" % len(FILES))
    for path in FILES:
        print("  + %s" % path)


if __name__ == "__main__":
    main()

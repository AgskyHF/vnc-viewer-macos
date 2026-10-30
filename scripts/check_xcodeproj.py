#!/usr/bin/env python3
"""Sanity-check an Xcode project file (old-style plist).

Catches the usual mistakes when editing project.pbxproj by hand:
  * unbalanced braces or an unclosed section
  * an object id that is defined twice
  * a source file in the build phase whose path does not exist on disk
  * a source file in the group that never reaches the build phase

Paths are resolved through the PBXFileReference entries, because a file may
live in a subfolder (or a submodule) while appearing in the group by its
plain name.

An id legitimately appears many times (its definition plus every reference),
so duplicates are detected by looking for two *definitions* of the same id.
"""

import os
import re
import sys

SOURCE_EXT = (".m", ".c", ".swift", ".cpp", ".mm")


def main():
    path = sys.argv[1]
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()

    problems = []

    for opener, closer in (("{", "}"), ("(", ")")):
        if text.count(opener) != text.count(closer):
            problems.append("unbalanced %s%s: %d vs %d"
                            % (opener, closer, text.count(opener), text.count(closer)))

    for section in re.findall(r"/\* Begin (\w+) section \*/", text):
        if ("/* End %s section */" % section) not in text:
            problems.append("section %s is not closed" % section)

    definitions = re.findall(r"^\t\t([0-9A-F]{24}) /\*.*?\*/ = \{", text, re.M)
    seen, duplicates = set(), set()
    for i in definitions:
        if i in seen:
            duplicates.add(i)
        seen.add(i)
    if duplicates:
        problems.append("ids defined twice: %s" % ", ".join(sorted(duplicates)))

    # fileRef id -> relative path inside the Source group
    file_paths = {}
    ref_block = re.search(r"/\* Begin PBXFileReference section \*/(.*?)/\* End PBXFileReference section \*/",
                          text, re.S)
    if ref_block:
        for line in ref_block.group(1).splitlines():
            m = re.match(r"\t\t([0-9A-F]{24}) /\*.*?\*/ = \{isa = PBXFileReference;.*?path = ([^;]+);",
                         line)
            if m:
                file_paths[m.group(1)] = m.group(2).strip().strip('"')

    # Build file id -> fileRef id
    build_block = re.search(r"/\* Begin PBXBuildFile section \*/(.*?)/\* End PBXBuildFile section \*/",
                            text, re.S)
    build_ref = {}
    if build_block:
        for line in build_block.group(1).splitlines():
            m = re.match(r"\t\t([0-9A-F]{24}) /\*.*?\*/ = \{isa = PBXBuildFile; fileRef = ([0-9A-F]{24})",
                         line)
            if m:
                build_ref[m.group(1)] = m.group(2)

    xcodeproj_dir = os.path.dirname(os.path.abspath(path))
    source_dir = os.path.join(os.path.dirname(xcodeproj_dir), "Source")

    phase = re.search(r"[0-9A-F]{24} /\* Sources \*/ = \{.*?files = \((.*?)\);", text, re.S)
    if not phase:
        problems.append("no Sources build phase found")
        return report(problems)

    compiled_names = set()
    for build_id in re.findall(r"([0-9A-F]{24}) /\* [^*]+? in Sources \*/", phase.group(1)):
        ref_id = build_ref.get(build_id)
        rel = file_paths.get(ref_id)
        if rel is None:
            continue
        name = os.path.basename(rel)
        compiled_names.add(name)
        if rel.endswith(SOURCE_EXT):
            if not os.path.exists(os.path.join(source_dir, rel)):
                problems.append("build phase compiles %s but it is not on disk" % rel)

    group = re.search(r"[0-9A-F]{24} /\* Source \*/ = \{.*?children = \((.*?)\);", text, re.S)
    if group:
        for ref_id in re.findall(r"([0-9A-F]{24}) /\*", group.group(1)):
            rel = file_paths.get(ref_id)
            if rel is None or not rel.endswith(SOURCE_EXT):
                continue
            name = os.path.basename(rel)
            if name not in compiled_names:
                problems.append("%s is in the group but not compiled" % rel)

    return report(problems)


def report(problems):
    if problems:
        print("PROJECT PROBLEMS:")
        for p in problems:
            print("  -", p)
        return 1
    print("project file OK: sections balanced, ids unique, build phase matches disk")
    return 0


if __name__ == "__main__":
    sys.exit(main())

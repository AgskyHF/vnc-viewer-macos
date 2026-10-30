#!/usr/bin/env python3
"""Rename the product from "Chicken Fork" to "VNC Viewer".

Touches, in one pass:
  * the Xcode target, product and build settings in project.pbxproj
  * the shared scheme (file name and its BuildableName/BlueprintName)
  * the bundle identifier
  * the user-visible names in Info.plist
  * the workflow scripts that look for the built .app

Renaming the scheme file means the workflow's -scheme argument has to match,
so that is rewritten too.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
OLD = "Chicken Fork"
NEW = "VNC Viewer"
NEW_ID = "ru.gsky.vncviewer"

pbx = ROOT / "cotvnc/ChickenFork.xcodeproj/project.pbxproj"
scheme_dir = pbx.parent / "xcshareddata/xcschemes"
plist = ROOT / "cotvnc/Resources/Info.plist"
workflow = ROOT / ".github/workflows/build.yml"
build_script = ROOT / "scripts/build_dmg.sh"

# --- project.pbxproj -------------------------------------------------------
text = pbx.read_text(encoding="utf-8")
text = text.replace('"%s.app"' % OLD, '"%s.app"' % NEW)
text = text.replace('/* %s */' % OLD, '/* %s */' % NEW)
text = text.replace('name = "%s";' % OLD, 'name = "%s";' % NEW)
text = text.replace('productName = "%s";' % OLD, 'productName = "%s";' % NEW)
text = text.replace('PRODUCT_NAME = "%s";' % OLD, 'PRODUCT_NAME = "%s";' % NEW)
text = text.replace('PRODUCT_BUNDLE_IDENTIFIER = net.sourceforge.chicken;',
                    'PRODUCT_BUNDLE_IDENTIFIER = %s;' % NEW_ID)
pbx.write_text(text, encoding="utf-8")
print("pbxproj: renamed target/product, bundle id -> %s" % NEW_ID)

# --- scheme ----------------------------------------------------------------
old_scheme = scheme_dir / ("%s.xcscheme" % OLD)
new_scheme = scheme_dir / ("%s.xcscheme" % NEW)
if old_scheme.exists():
    s = old_scheme.read_text(encoding="utf-8")
    s = s.replace('BuildableName = "%s.app"' % OLD, 'BuildableName = "%s.app"' % NEW)
    s = s.replace('BlueprintName = "%s"' % OLD, 'BlueprintName = "%s"' % NEW)
    new_scheme.write_text(s, encoding="utf-8")
    old_scheme.unlink()
    print("scheme: %s.xcscheme -> %s.xcscheme" % (OLD, NEW))

# --- Info.plist ------------------------------------------------------------
p = plist.read_text(encoding="utf-8")
p = p.replace("<string>%s</string>" % OLD, "<string>%s</string>" % NEW)
p = p.replace("Copyright © 2002-2006 Geekspiff, 2010-2011 Chicken developers, 2022-2026 ays7",
              "Copyright © 2002-2006 Geekspiff, 2010-2011 Chicken developers, 2022-2026 ays7, "
              "2026 VNC Viewer contributors")
plist.write_text(p, encoding="utf-8")
print("Info.plist: display name -> %s" % NEW)

# --- workflow --------------------------------------------------------------
w = workflow.read_text(encoding="utf-8")
w = w.replace('-scheme "%s"' % OLD, '-scheme "%s"' % NEW)
w = w.replace('-name "$SCHEME.app"', '-name "$SCHEME.app"')
workflow.write_text(w, encoding="utf-8")
print("build.yml: -scheme -> %r" % NEW)

# --- build script ----------------------------------------------------------
b = build_script.read_text(encoding="utf-8")
b = b.replace('SCHEME="%s"' % OLD, 'SCHEME="%s"' % NEW)
b = b.replace('DMG="$DIST/VNC-Viewer-${VERSION}.dmg"', 'DMG="$DIST/VNC-Viewer-${VERSION}.dmg"')
build_script.write_text(b, encoding="utf-8")
print("build_dmg.sh: SCHEME -> %r" % NEW)

# --- verify ----------------------------------------------------------------
print()
print("=== leftovers ===")
for path in [pbx, plist, workflow, build_script]:
    hits = [i + 1 for i, line in enumerate(path.read_text(encoding="utf-8").splitlines())
            if OLD in line]
    if hits:
        print("  %s: lines %s" % (path.name, hits[:6]))
print("done")

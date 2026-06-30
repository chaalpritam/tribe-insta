#!/usr/bin/env bash
# xcodegen omits the package= link on XCSwiftPackageProductDependency for local
# packages; Xcode GUI then shows "Missing package product 'TribeCore'".
set -euo pipefail
PBX="tribe-insta.xcodeproj/project.pbxproj"
[[ -f "$PBX" ]] || { echo "patch-tribecore-package: $PBX not found" >&2; exit 1; }

# Remote package references don't need this patch.
if grep -q 'XCRemoteSwiftPackageReference' "$PBX"; then
  exit 0
fi

if grep -A4 'isa = XCSwiftPackageProductDependency;' "$PBX" | grep -q 'package ='; then
  exit 0
fi

REF_LINE=$(grep -m1 'XCLocalSwiftPackageReference' "$PBX" || true)
[[ -n "$REF_LINE" ]] || exit 0

REF_ID=$(printf '%s' "$REF_LINE" | sed -E 's/[[:space:]]+([A-F0-9]+) .*/\1/')
REF_LABEL=$(printf '%s' "$REF_LINE" | sed -E 's/.*(\/\* XCLocalSwiftPackageReference .* \*\/).*/\1/')

export REF_ID REF_LABEL
perl -i -pe '
  if (/isa = XCSwiftPackageProductDependency;/) { $in = 1; }
  if ($in && /productName = TribeCore;/ && !/package =/) {
    $_ = "\t\t\tpackage = $ENV{REF_ID} $ENV{REF_LABEL};\n$_";
    $in = 0;
  }
' "$PBX"

echo "patch-tribecore-package: linked TribeCore product to local package reference"

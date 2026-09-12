#!/usr/bin/env bash
# Checks Core/AppDate.swift, in particular that the wire format cannot follow the
# device's calendar. Run after touching AppDate.swift:
#
#   ./scripts/check-date.sh
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d)
# Swift only allows top-level statements in a file literally named main.swift.
cp scripts/date-checks.swift "$out/main.swift"
swiftc -O "Invo Billing/Core/AppDate.swift" "$out/main.swift" -o "$out/checks"
"$out/checks"
status=$?
rm -rf "$out"
exit $status

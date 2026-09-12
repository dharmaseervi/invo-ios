#!/usr/bin/env bash
# Checks Core/Money.swift against its expected output.
#
# There is no test target in this project, so this compiles the formatter on its own and
# asserts what it produces. Run it after touching Money.swift:
#
#   ./scripts/check-money.sh
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d)
# Swift only allows top-level statements in a file literally named main.swift.
cp scripts/money-checks.swift "$out/main.swift"
swiftc -O "Invo Billing/Core/Money.swift" "$out/main.swift" -o "$out/checks"
"$out/checks"
status=0
"$out/checks" | grep -q FAIL && status=1
rm -rf "$out"
exit $status

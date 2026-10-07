#!/usr/bin/env bash
# Run with: bash scripts/check-expenses.sh
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
cp scripts/expense-checks.swift "$out/main.swift"
swiftc -module-cache-path "$out/modules" \
    "Invo Billing/Features/expensess/model/model.swift" "$out/main.swift" -o "$out/checks"
"$out/checks"

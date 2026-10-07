#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
cp scripts/purchase-checks.swift "$out/main.swift"
swiftc -module-cache-path "$out/modules" \
    "Invo Billing/Features/purchases/model/PurchaseModels.swift" "$out/main.swift" -o "$out/checks"
"$out/checks"

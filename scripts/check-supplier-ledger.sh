#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
    -module-cache-path "$out/modules" \
    "Invo Billing/Features/purchases/model/PurchaseModels.swift" \
    "Invo Billing/Features/purchases/viewModel/PurchaseLedgerViewModel.swift" \
    scripts/supplier-ledger-checks.swift -o "$out/checks"
"$out/checks"

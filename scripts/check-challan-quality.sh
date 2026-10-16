#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
swiftc -module-cache-path "$out/cache" -parse-as-library \
  'Invo Billing/Features/challan/model/ChallanModel.swift' \
  'Invo Billing/Features/challan/viewModel/ChallanViewModel.swift' \
  scripts/challan-quality-checks.swift -o "$out/checks"
"$out/checks"

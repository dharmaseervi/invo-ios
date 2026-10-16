#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
swiftc -module-cache-path "$out/cache" -parse-as-library \
  'Invo Billing/Core/SafeCSV.swift' \
  'Invo Billing/Features/reports/model/GSTReportModel.swift' \
  'Invo Billing/Features/reports/viewModel/GSTReportViewModel.swift' \
  scripts/report-quality-checks.swift -o "$out/checks"
"$out/checks"

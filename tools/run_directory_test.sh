#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

PYTHON_BIN="python3"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  PYTHON_BIN="python"
fi

echo "🔍 Validating required directories and data files (using $PYTHON_BIN)..."

failures=0

check_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "❌ Missing required directory: $dir"
    failures=1
  else
    echo "✅ Directory present: $dir"
  fi
}

validate_json() {
  local file="$1"
  local label="$2"
  if [[ ! -f "$file" ]]; then
    echo "❌ Missing $label file: $file"
    failures=1
    return
  fi

  if "$PYTHON_BIN" - "$file" >/dev/null 2>&1 <<'PY'
import json
import sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as fh:
    json.load(fh)
PY
  then
    echo "✅ $label JSON is valid: $file"
  else
    echo "❌ $label JSON is invalid: $file"
    failures=1
  fi
}

check_dir "inputs"
check_dir "data"
check_dir "config"

validate_json "inputs/accounts.json" "Chart of accounts"
validate_json "inputs/supplier_list.json" "Supplier list"
validate_json "data/general_journal.json" "General journal"
validate_json "config/mcp_servers.json" "MCP server configuration"

if [[ ! -f "inputs/accounting_rules.txt" ]]; then
  echo "❌ Missing accounting rules file: inputs/accounting_rules.txt"
  failures=1
else
  echo "✅ Accounting rules file present"
fi

if [[ "$failures" -ne 0 ]]; then
  echo "❌ Directory verification failed."
  exit 1
fi

echo "🎉 Directory verification passed."

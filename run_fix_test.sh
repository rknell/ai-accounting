#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo "🧹 Checking formatting..."
dart format --output=none --set-exit-if-changed \
  bin \
  lib \
  mcp \
  test \
  tools \
  verify_cleanup.dart

echo "🔍 Running analyzer..."
dart analyze

echo "🛠️  Replaying targeted fix-related tests..."
dart test test/services/transaction_categorizer_test.dart

echo "🎉 Fix verification succeeded."

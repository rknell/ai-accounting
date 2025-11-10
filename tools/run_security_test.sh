#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

echo "🛡️ Running security regression checks..."

HOOKS_PATH="$(git config --get core.hooksPath || echo '')"
if [[ "$HOOKS_PATH" != ".githooks" ]]; then
  echo "ℹ️  Configuring git hooks path to use .githooks"
  git config core.hooksPath .githooks
fi

if [[ ! -x ".githooks/pre-commit" ]]; then
  echo "❌ .githooks/pre-commit must be executable"
  exit 1
fi

if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
  echo "⚠️  DEEPSEEK_API_KEY is not set. Timeout tests may rely on cached data."
fi

echo "⏱️  Validating MCP timeout behaviour..."
dart test test/mcp_client_timeout_test.dart
dart test test/mcp_tools_list_timeout_test.dart

echo "🎉 Security regression suite passed."

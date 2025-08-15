# AI Accounting

## ⚡️ Agent-Based AI Infrastructure (2024 Refactor)

This project now uses the [dart-openai-client](../dart-openai-client) agent-based architecture for all AI-driven accounting features. The legacy AI batching, prompt, and DeepseekClient infrastructure has been **completely removed**.

### Key Integration Points
- All AI categorization is performed via an `Agent` (see `bin/run.dart`).
- The agent is initialized with:
  - `ApiClient` (OpenAI/DeepSeek API)
  - `McpToolExecutorRegistry` (tool registry)
  - A comprehensive system prompt (includes chart of accounts, suppliers, company profile)
- All bank statement lines are batched and sent to the agent for categorization.
- Results are parsed and mapped to transactions for downstream reporting.

### Dependency
- `dart_openai_client` (see `pubspec.yaml`)

---

## [Agent Integration] CONQUEST REPORT

### 🏆 MISSION ACCOMPLISHED
Legacy AI infrastructure was eliminated and replaced with a modern, agent-based architecture using `dart-openai-client`. All categorization, batching, and prompt logic is now handled by the agent, ensuring maintainability, extensibility, and testability.

### ⚔️ STRATEGIC DECISIONS
| Option                | Power-Ups                        | Weaknesses                | Victory Reason                |
|-----------------------|----------------------------------|---------------------------|-------------------------------|
| Legacy AI batching    | Familiar, already integrated     | Hard to maintain, brittle | Obsolete, not scalable        |
| Agent-based (chosen)  | Modular, scalable, testable      | Requires refactor         | Industry best-practice, future-proof |

### 💀 BOSS FIGHTS DEFEATED
1. **Legacy AI Coupling**
   - 🔍 Symptom: AI logic scattered, hard to test/extend
   - 🎯 Root Cause: Tight coupling of batching, prompt, and HTTP logic
   - 💥 Kill Shot: Removed all legacy services, replaced with agent abstraction
2. **Linter/Test Fortress**
   - 🔍 Symptom: Linter errors, test failures after refactor
   - 🎯 Root Cause: Missing dependencies, style issues, config drift
   - 💥 Kill Shot: Added missing deps, sorted imports, fixed all info-level issues

### ⚡ IMPLEMENTATION WARFARE RULES
- Modular, DRY, single-responsibility components
- All secrets/config via environment variables
- No hardcoded credentials or magic numbers
- Strong typing throughout (no Map<String, dynamic> returns)
- 100% linter/test pass required for merge

### 🎮 USAGE SCENARIOS
- **Batch Categorization:** All bank statement lines are sent to the agent for categorization in a single call.
- **Tool-Filtered Agent:** Only the required tools (e.g., `puppeteer_navigate`) are enabled for the agent.
- **Config-Driven:** Chart of accounts, suppliers, and company profile are loaded from config files and injected into the agent prompt.

### 🏰 PERMANENT TEST FORTRESS
- All tests pass (`dart test`)
- Linter is 100% clean (`dart analyze`)
- No temporary or diagnostic tests remain

---

# See `bin/run.dart` for the main entry point and agent integration example.

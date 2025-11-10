<!-- AI Accounting Agent Playbook -->

# AI Accounting — Agent Operations Manual

This file is your dedicated guide for contributing with automation support. Follow every mandate here before writing code, opening PRs, or landing commits. The contents align with the [AGENTS.md guidelines](https://agents.md/) and the repository standards.

---

## 1. Mission Overview
- Purpose: AI-assisted bookkeeping using Dart MCP servers plus CLI agents.
- Core repos/services live under `lib/`, `mcp/`, `services/`, and `bin/`.
- Unified accounting data lives at `data/company_file.json` (override via `AI_ACCOUNTING_COMPANY_FILE`). Legacy directories `inputs/` and `data/` remain read-only fallbacks for migrations/tests.
- Every change must preserve journal integrity (never introduce negative journal amounts—swap debit/credit instead).

## 2. Environment & Setup
- Install Dart SDK 3.6 (see `pubspec.yaml`).
- Fetch dependencies: `dart pub get`.
- Export required secrets before running agents:
  - `DEEPSEEK_API_KEY` (or other OpenAI-style key) for AI-backed flows.
  - Optional MCP configuration overrides via `AI_ACCOUNTING_*` env vars.
- MCP registry config: `config/mcp_servers.json`. Confirm new servers are registered here.
- Start local automations (as needed):
  - Accountant MCP server: launched automatically by the registry.
  - Terminal MCP server: provides guarded shell access.
  - Context manager, Puppeteer, and filesystem servers: enable selectively via config.

## Quick Setup Commands
```bash
dart pub get
export DEEPSEEK_API_KEY=sk-...    # required for AI-backed flows
dart analyze
dart test
dart run test/run_mcp_tests.dart  # MCP-focused regression runner
```
Agents and CI use these commands to validate changes automatically per the AGENTS.md convention ([agents.md](https://agents.md/)).

## 3. Command Arsenal
- Bootstrap: `dart pub get`
- Static analysis (mandatory before completion): `dart analyze`
- Test suites (mandatory before completion):
  - Full run: `dart test`
  - Focused group: `dart test test/<path_to_test>.dart`
  - MCP regression runner: `dart run test/run_mcp_tests.dart`
- Helper scripts (under `tools/`):
  - `./tools/run_directory_test.sh`
  - `./tools/run_fix_test.sh`
  - `./tools/run_security_test.sh`
  - `./tools/run_failed_tests_only.sh [<dart test args>]` — wraps `dart test --reporter json` and prints a concise summary of only the failing cases; use this instead of raw `dart test` during development.
- Helper automation must be implemented in Dart or shell scripts—Python (and other runtimes) are not allowed for repo tooling.
- Formatter: `dart format <paths>` (ensure no formatting drift).

## 4. Development Workflow (Tests-First Doctrine)
1. **Define the change** — capture requirements/tests in this manual or linked docs before implementation.
2. **Write/extend a failing test** covering the new feature, bug fix, or regression. No feature work proceeds without test coverage.
3. **Implement the solution** using modular, reusable patterns (see Section 6).
4. **Run `dart analyze` and `dart test`** locally. Both MUST pass; no exceptions.
5. **Document updates** — update relevant docs (`AGENTS.md`, `docs/ARCHITECTURE.md`, `INSTRUCTIONS.md`, or others) to keep the knowledge base current.

### Completion Gate
> All work is incomplete until `dart analyze` and `dart test` finish successfully. Record command output (or summarise) in your PR/commit description.

## 5. Testing Fortress
- **Mandatory coverage** for every feature and bug fix. Keep permanent regression tests under `test/`.
- Follow naming convention from `test/README.md` (`🛡️ REGRESSION`, `✅ FEATURE`, `🎯 EDGE_CASE`, `⚡ PERFORMANCE`, `🔧 INTEGRATION`).
- Use GetIt overrides (`Services(testMode: true)`) for deterministic tests.
- Never mutate live data in `inputs/` or `data/`; clone fixtures when tests require writes.
- Integration with MCP servers goes through `McpToolExecutorRegistry`; provide mocks for isolated unit tests when reasonable.

## Testing Instructions
- Run analyzer and full tests locally before committing:
  - `dart analyze`
  - `dart test`
  - `dart run test/run_mcp_tests.dart` (MCP regression suite)
- To focus on a single suite: `dart test test/<relative_path>.dart`
- Fix all analyzer warnings and test failures before marking work complete.

## 6. Coding & Architecture Standards
- Adhere to patterns in `docs/ARCHITECTURE.md` and `.cursor/rules/universal_rules.mdc` (when present):
  - MCP servers extend `BaseMCPServer` and register via `McpToolExecutorRegistry`.
  - Services are resolved through the shared `services` singleton (`lib/services/services.dart`).
  - Scripts live in `bin/`; reusable logic in `lib/`; test-only helpers in `test/`.
- **Strong typing supremacy** — never return `Map<String, dynamic>` from APIs unless within `fromJson`/`toJson`. Prefer dedicated value classes with serializers.
- **Null safety discipline** — avoid `late` and `!` except in sanctioned framework cases; use shadow variables and null-aware operators.
- **Generality mandate** — zero magic numbers or single-use hacks. Extract constants and make solutions reusable.
- **Performance annotations** — mark non-trivial complexity or optimisations with `// PERF:` comments (include rationale).
- **Temporary workarounds** — document with `// WORKAROUND: <limitation> (Expires: <date>)`.

## Code Style
- Use Dart null safety throughout; avoid `late` and `!` (tests may assert non-null explicitly).
- Follow `lints` v3 rules; keep analyzer warnings at zero.
- Prefer dedicated value types over dynamic maps; only parse JSON maps within `fromJson`.
- Keep functions short, use guard clauses, and avoid deep nesting.
- Format with `dart format` and keep diffs focused on logical changes.

## 7. Tooling & Automation
- MCP servers available:
  - `mcp/mcp_server_accountant.dart` — supplier CRUD, transaction search/update. Observe bank account protection (001–099).
  - `mcp/mcp_server_terminal.dart` — guarded shell commands (blacklist, timeouts).
  - `mcp/mcp_server_dart.dart` — exposes analyzer/test helpers.
  - `mcp/mcp_server_context_manager.dart` — manages long-session context.
  - `mcp/mcp_server_puppeteer.dart` — browser automation (optional).
- When adding tools:
  - Register in `config/mcp_servers.json`.
  - Provide regression tests hitting the tool path.
  - Document usage and failure modes here and in `docs/ARCHITECTURE.md`.

## 8. Data Governance & Safety
- Unified company file backups stored in `data/backups/` on each save; maintain this behaviour.
- Honor environment overrides (`AI_ACCOUNTING_INPUTS_DIR`, `AI_ACCOUNTING_DATA_DIR`, `AI_ACCOUNTING_CONFIG_DIR`) for tests and custom fixtures.
- Never delete or mutate `inputs/` / `data/` reference files directly. Copy to a sandbox if write access is required.
- Sensitive configuration (API keys, credentials) must remain in environment variables; never commit secrets.

## 9. Documentation Discipline
- Update `docs/ARCHITECTURE.md`, `INSTRUCTIONS.md`, and relevant READMEs when behaviour changes.
- Summarise architectural decisions (motivation, alternatives, trade-offs) in commit/PR descriptions.
- Remove TODO comments by converting them into tracked issues or backlog items; no lingering TODOs in code.
- Keep this `AGENTS.md` accurate—revise immediately when process/command changes.

## PR Instructions
- Title format: `[ai-accounting] <concise title>`
- Before pushing:
  - Run `dart analyze` and ensure 0 issues.
  - Run `dart test` and ensure all pass (including MCP runner).
  - Update docs (`AGENTS.md`, `docs/ARCHITECTURE.md`, `INSTRUCTIONS.md`) for any behavior changes.
- In PR description:
  - Summarize the change and link the tests that cover it.
  - Paste or summarize analyzer/test outputs.

## 10. Contribution Checklist
- [ ] Requirements captured and documented.
- [ ] Failing test written/extended.
- [ ] Implementation aligns with architecture + generalisation mandates.
- [ ] `dart analyze` passes.
- [ ] `dart test` passes.
- [ ] Documentation updated (including this file if guidance changed).
- [ ] Security and data handling verified.
- [ ] PR/commit message references tests run and decisions made.

---

Stay disciplined. Run tests first, keep analyzer green, document every battle scar, and preserve the accounting ledger with zero tolerance for data corruption.

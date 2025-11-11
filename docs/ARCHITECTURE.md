# Architecture & Operations

This project combines AI-powered categorisation with a suite of Model Context Protocol (MCP) servers. The goal of this document is to keep the essentials in one place so you can understand how the pieces fit together without chasing multiple guides.

## Data & Configuration
- **Unified company file**: all live accounting data (chart of accounts, suppliers, accounting rules, company profile, and general journal) is stored in a single JSON snapshot. The default path is `data/company_file.json`, overridable via `AI_ACCOUNTING_COMPANY_FILE`. Keep all user data in this one file; avoid writing to legacy `inputs/` JSON except for migration/tests. To run multiple sets of books, set a distinct `AI_ACCOUNTING_COMPANY_FILE` per company.
- **Automatic migration**: on startup `CompanyFileService.ensureCompanyFileReady()` loads the configured JSON. If it is missing, the service migrates from the legacy `inputs/` / `data/` files, writes the new snapshot, and continues. Backups land in `data/backups/` before every save.
- **Legacy overrides**: `AI_ACCOUNTING_INPUTS_DIR`, `AI_ACCOUNTING_DATA_DIR`, and `AI_ACCOUNTING_CONFIG_DIR` are still honoured so fixtures/tests can point at custom directories. When the unified file is unavailable or migration fails, services fall back to these directories transparently.
- **Environment**: set `DEEPSEEK_API_KEY` before running any agent entry point. Additional MCP-specific environment variables can be set inside `config/mcp_servers.json`.
- **MCP registry**: `config/mcp_servers.json` lists all servers. Each entry maps directly to a `McpServerConfig` used by `McpToolExecutorRegistry`.

## MCP Servers
| Name | File | Purpose | Notes |
|------|------|---------|-------|
| `accountant` | `mcp/mcp_server_accountant.dart` | Supplier CRUD, fuzzy matching, transaction search/update, report regeneration | Uses per-server tools-list timeout (15 s). Respects bank-account protection (001‑099) and never deletes journal data. |
| `terminal` | `mcp/mcp_server_terminal.dart` | Executes vetted shell commands for agents | Enforces a command blacklist, working-directory guardrails, timeouts, and full stdout/stderr capture. |
| `dart` | `mcp/mcp_server_dart.dart` | Runs `dart analyze`, `dart test`, and helper workflows | Useful for self-hosted analysis/fix commands. |
| `filesystem` | external (`@modelcontextprotocol/server-filesystem`) | Read/write helpers for files | Provides directory trees, file metadata, etc. |
| `context-manager` | `mcp/mcp_server_context_manager.dart` | Token-aware context operations | Exposes tools for tracking, cleaning, and summarising context when driving long sessions. |
| `puppeteer` | `mcp/mcp_server_puppeteer.dart` | Web automation/scraping | Optional; disabled if the binary is unavailable. |

All servers extend `BaseMCPServer` from `dart_openai_client`, so lifecycle (initialize → tools/list → tools/call) is consistent. Start new servers by adding them to the config file; the registry handles discovery and tool registration automatically.

## Agent & CLI Entry Points
- `bin/categorise_transactions.dart` – walks uncategorised journal entries, calls `match_supplier_fuzzy`, and applies account updates via MCP tools. Relies on `services.generalJournal` and the accountant server.
- `bin/ai_coding_assistant.dart` / `bin/life_coach_ui.dart` – interactive command-line helpers that use the same MCP registry for tooling.
- `bin/accounting_agent_ui.dart` – conversational UI designed for accountants; prompts feed directly into the accountant server for investigation flows (search by string, supplier remapping, etc.).

All entry points share the same setup pattern:
1. Load `config/mcp_servers.json`.
2. Instantiate `McpToolExecutorRegistry` and call `initialize()` (which launches each server and discovers tools).
3. Pass the registry into whichever agent/client is running so tool execution can be routed centrally.

## Shared Services
- The `services` getter in `lib/services/services.dart` lazily registers a `Services` singleton with GetIt. Access services through this getter so MCP servers, entry points, and tests share the same instances.
- `ChartOfAccountsService` and `GeneralJournalService` now load/save through the unified company file first, falling back to the legacy directories only when the file is unavailable. They still respect the `AI_ACCOUNTING_INPUTS_DIR`/`AI_ACCOUNTING_DATA_DIR` overrides so integration tests and fixtures stay isolated.
- When writing tests that need custom behaviour, register your own `Services(testMode: true)` with GetIt, or override specific services before invoking MCP handlers.
- `SupplierSpendTypeService` reads `config/supplier_spend_types.json` (respecting `AI_ACCOUNTING_CONFIG_DIR`) and exposes lookups for the Supplier Spend Type report so vendor cadence changes stay declarative.

## Code Organization Guidelines
- Avoid ad-hoc Dart scripts in the repository root. If you need to exercise behaviour, add a proper unit/integration test under `test/`.
- Tooling/maintenance scripts belong in `tools/`; wire them into CI as needed.
- Consumer-facing entry points belong in `bin/` so they can be invoked via `dart run`.

## Terminal Security Snapshot
- **Allowed**: typical developer tooling (`git`, `dart`, `ls`, etc.).
- **Blocked**: destructive commands (`rm -rf /`, `dd if=/dev/...`, privilege-escalation helpers) and any command outside the configured working-tree.
- **Resource guards**: every invocation has a timeout and output-size clamp; processes are cleaned up on failure.

## Performance & Resilience Notes
- **Suppliers source of truth**: suppliers are read from the unified company file when available and automatically added when discovered by categorisation/import flows. Legacy `inputs/supplier_list.json` is only used as a fallback for older setups.
- **Supplier cache**: the accountant server caches `supplier_list.json` for five minutes (or until the file timestamp changes) when falling back to legacy mode.
- **Timeout budgets**: `tools/list` requests default to 3 s, but heavyweight servers such as `accountant` request a 15 s window during discovery. Individual `tools/call` invocations should continue to pass explicit `timeout` values when they need stricter bounds.
- **Web research**: tests disable web research when they assert latency-sensitive behaviour. Production categorisation keeps the default settings, but agents can pass `enableWebResearch: false` when they need deterministic responses.
- **Supplier research cache**: when web research or manual creation provides a raw transaction description, the accountant server now stores the interpreted summary as `researchNotes` and records cleaned aliases. `match_supplier_fuzzy` scores these aliases/keywords so future runs auto-match with higher confidence.
- **IO redirection**: entry points honour the `AI_ACCOUNTING_*` overrides noted above so you can run smoke tests (or CI) against temporary directories without touching the real books.

## Testing & Verification
- Static analysis: `dart analyze`
- Unit/integration tests: `dart test` (full suite) or granular targets under `test/mcp_server/` and `test/models/`
- Helper scripts (in `tools/`): `run_directory_test.sh`, `run_fix_test.sh`, `run_security_test.sh`
- **Rule of thumb**: no feature or regression fix ships without automated tests covering the behaviour; treat failing tests as the signal to code, not the other way around.

Keep this file up to date whenever you add/remove an MCP server, change data locations, or introduce new entry points. EOF

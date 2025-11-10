# Architecture & Operations

This project combines AI-powered categorisation with a suite of Model Context Protocol (MCP) servers. The goal of this document is to keep the essentials in one place so you can understand how the pieces fit together without chasing multiple guides.

## Data & Configuration
- **Company data** lives in `inputs/` (chart of accounts, suppliers, accounting rules, company profile) and `data/` (general journal). `CompanyFileService` loads these resources, provides validation, and can export/import combined snapshots.
- **Overrides**: set `AI_ACCOUNTING_INPUTS_DIR`, `AI_ACCOUNTING_DATA_DIR`, or `AI_ACCOUNTING_CONFIG_DIR` to point the tooling at alternate working directories (useful for fixtures/tests). When unset, binaries fall back to the repo defaults.
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

## Terminal Security Snapshot
- **Allowed**: typical developer tooling (`git`, `dart`, `ls`, etc.).
- **Blocked**: destructive commands (`rm -rf /`, `dd if=/dev/...`, privilege-escalation helpers) and any command outside the configured working-tree.
- **Resource guards**: every invocation has a timeout and output-size clamp; processes are cleaned up on failure.

## Performance & Resilience Notes
- **Supplier cache**: the accountant server caches `supplier_list.json` for five minutes (or until the file timestamp changes). This avoids re-reading JSON for every categorisation request while still picking up edits promptly.
- **Timeout budgets**: `tools/list` requests default to 3 s, but heavyweight servers such as `accountant` request a 15 s window during discovery. Individual `tools/call` invocations should continue to pass explicit `timeout` values when they need stricter bounds.
- **Web research**: tests disable web research when they assert latency-sensitive behaviour. Production categorisation keeps the default settings, but agents can pass `enableWebResearch: false` when they need deterministic responses.
- **IO redirection**: entry points honour the `AI_ACCOUNTING_*` overrides noted above so you can run smoke tests (or CI) against temporary directories without touching the real books.

## Testing & Verification
- Static analysis: `dart analyze`
- Unit/integration tests: `dart test` (full suite) or granular targets under `test/mcp_server/` and `test/models/`
- Helper scripts: `run_directory_test.sh`, `run_fix_test.sh`, `run_security_test.sh`

Keep this file up to date whenever you add/remove an MCP server, change data locations, or introduce new entry points. EOF

# AI Accounting

Modern AI-assisted bookkeeping toolkit built in Dart. The project pairs a suite of MCP servers (accountant, terminal, context manager, filesystem, Dart) with command-line agents that categorise transactions, investigate suppliers, and keep the general journal in sync with business rules.

## Key Features
- **Agent-based categorisation** – `bin/categorise_transactions.dart` finds uncategorised entries and applies updates through MCP tools such as `match_supplier_fuzzy` and `update_transaction_account`.
- **Accountant MCP server** – exposes supplier CRUD, fuzzy matching, transaction search/update, and report regeneration while enforcing GST and bank-account protections.
- **Secure terminal access** – the terminal MCP server executes vetted shell commands with blacklisted patterns, working-directory guardrails, and timeouts.
- **Context-aware utilities** – the context-manager server keeps long-running sessions within token budgets.
- **Rich test suite** – targeted regression tests cover chart of accounts, supplier management, MCP timeouts, and the accountant server workflows.

## Getting Started
1. Install Dart 3.x and run `dart pub get`.
2. Export your DeepSeek/OpenAI key: `export DEEPSEEK_API_KEY=sk-...`.
3. Verify MCP config: `config/mcp_servers.json` should include every server you want to run (accountant requires local file access to `inputs/` and `data/`).
4. (Optional) Point `AI_ACCOUNTING_COMPANY_FILE` at the unified JSON file you want to use. When absent, the tooling will auto-create `data/company_file.json` by migrating the legacy `inputs/` + `data/` resources.

### Single-file company data
- `CompanyFileService` now keeps the chart of accounts, general journal, suppliers, rules, and company profile inside a single JSON snapshot (default: `data/company_file.json`).
- Set `AI_ACCOUNTING_COMPANY_FILE=/path/to/MyCompany.json` to isolate multiple books on the same machine.
- Existing services (`ChartOfAccountsService`, `GeneralJournalService`, importer scripts) read/write through the unified file first and only fall back to the legacy directories if migration fails.
- Regenerate or refresh the company file at any time via `dart run bin/migrate_to_company_file.dart`; backups land in `data/backups/` before every save.

### Bank statement filename mapping
- CSV filenames normally match the bank account code in `inputs/accounts.json` (e.g. `001.csv`). When a statement uses an account number or descriptive title instead, add a mapping in `config/bank_account_mappings.json`.
- Keys are filenames without the `.csv` extension, values are the three-digit bank account code. The included sample maps `example_bank_statement`, `496 405 529`, and `414 180 291` to their matching accounts.
- The importer normalizes filenames (case/spacing), so `496405529.csv`, `496-405-529.csv`, and `496 405 529.csv` all hit the same mapping entry.
- Keep this file in sync with any new bank feeds so `dart run bin/import_transactions.dart` can ingest full-year statements without renaming them manually.

### Running the categorisation workflow
```bash
dart run bin/categorise_transactions.dart
```
This command loads uncategorised journal entries (account `999`), queries the accountant MCP server for supplier matches, and issues `update_transaction_account` calls with annotated notes.

### AI Accounting CLI
- Launch `dart run bin/ai_accounting.dart` for an interactive workflow that bundles importing, AI categorisation, report generation, filename-mapping management, and a menu of every other script under `bin/`.
- Option 1 runs the bulk importer, and option 2 lets you import any CSV (even outside `inputs/`) via `dart run bin/import_transactions.dart --file=/path/to/file.csv --bank=001`.
- Option 6 exports the full general journal as `date, description, supplier, account name, account code, credit, debit` rows so you can hand audited data to spreadsheets or other ledgers.
- The wizard lists available `inputs/*.csv` files, validates bank account codes against the chart of accounts, and appends new entries to `config/bank_account_mappings.json` without manual editing.

### Other entry points
- `dart run bin/accounting_agent_ui.dart` – conversational investigation assistant for accountants.
- `dart run bin/ai_coding_assistant.dart` / `dart run bin/life_coach_ui.dart` – developer-focused interactive shells that share the same MCP registry.

## Testing & Linting
```bash
dart analyze
dart test                  # entire suite
dart test path/to/test.dart # focused run
```
> 🧪 **Policy**: every new feature or bugfix must land with unit/integration tests. Write the failing test first, implement the fix, and keep the suite green before opening a PR.
Helper scripts (in `tools/`) provide lightweight guardrails:
- `./tools/run_directory_test.sh` – validates that `inputs/`, `data/`, and `config/` exist and that their JSON files are well-formed.
- `./tools/run_fix_test.sh` – ensures the formatter, analyzer, and fix-oriented unit tests are clean.
- `./tools/run_security_test.sh` – confirms `.githooks/pre-commit` is active and replays the MCP timeout/security regressions.

## Git Hooks
Enable the shared hooks to prevent commits when analysis or tests fail:

```bash
git config core.hooksPath .githooks
```

The `pre-commit` hook runs `dart analyze` and the full `dart test` suite; it aborts the commit if either command fails.

## Documentation
- `docs/ARCHITECTURE.md` – MCP servers, entry points, and operational notes.
- `INSTRUCTIONS.md` – business-specific transaction categorisation rules.
- `test/README.md` – structure of the MCP-focused test suites.

## Current Action Plan
1. **Performance & resilience review** – profile the fuzzy-supplier flow, add caching where it reduces duplicate tool calls, and document timeout budgets per server (accountant already uses a 15 s discovery window).
2. **Security & ergonomics polish** – run the security/directory helper scripts, document required environment variables, and make sure contributors know how the shared `Services` singleton is initialised when launching scripts/tests.
3. **Document & automate workflows** – wire the new integration tests/smoke tests into CI, and expand contributor docs with instructions for running MCP-backed tooling locally.

# GOAL

- To create a tool that will import an entire years works of bank statement records, accurately categorise the transactions, and generate a comprehensive financial reporting - balance sheets, profit and loss statements, GST returns, general journal.

- To be able to query and edit the output, with the assistance of a cli interface.

- Entirely accurate, and tests that the records that are imported are accurate and complete.

- Support for a full accounting system such as a chart of accounts, suppliers, accounting rules, company profile, and general journal.

- Onboarding interview at company file creation to collect business profile, tax settings, and operating policies; results stored in the unified company file.

- Bookkeeping and categorisation adapt to the declared business type and interview outputs (e.g., GST treatment, default accounts, rule weights, supplier handling).

- Load and continue to use a company file from a previous year, and continue to use the tooling to categorise the transactions, and generate the financial reporting.

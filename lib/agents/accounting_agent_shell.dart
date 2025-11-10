import 'dart:convert';
import 'dart:io';

import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:path/path.dart' as path;

/// Standardised special instructions to keep MyPost workflows consistent across
/// every accounting agent entry point.
const List<String> kAccountingAgentStandardSpecialInstructions = [
  'When a transaction references "MyPost", "MyPost Business", "MyPost Australia Post", or similar Australia Post portals, treat it as shipping/postage and assign account 208 "Postage" (COGS).',
  'Set or confirm the supplier name as "MyPost" when updating those transactions to keep reporting consistent.',
  'Provide reasoning about why the transaction belongs in COGS versus operating expenses before issuing updates.',
];

/// Immutable configuration for customizing the interactive accounting agent
/// shell.
class AccountingAgentShellConfig {
  /// Creates configuration for the accounting agent shell.
  const AccountingAgentShellConfig({
    required this.introTitle,
    required this.introDescription,
    required this.sessionIntro,
    this.promptLabel = 'Enter your accounting investigation',
    this.exitKeywords = const ['exit', 'quit', 'done'],
    this.temperature = 0.3,
    this.specialInstructions = const [],
    this.samplePrompts = const [],
    this.initialPrompt,
  });

  /// Title printed before the shell starts.
  final String introTitle;

  /// Short description printed under the title.
  final String introDescription;

  /// Messaging shown ahead of the interactive loop.
  final String sessionIntro;

  /// Label used for each prompt line.
  final String promptLabel;

  /// Words that end the session when typed by the user.
  final List<String> exitKeywords;

  /// Temperature used by the Agent instance.
  final double temperature;

  /// Extra system prompt instructions appended to the base template.
  final List<String> specialInstructions;

  /// Example prompts shown to the operator.
  final List<String> samplePrompts;

  /// Optional automated investigation that runs before interactive mode.
  final String? initialPrompt;
}

/// Interactive AI accounting shell backed by the MCP accountant server.
class AccountingAgentShell {
  /// Creates a shell runner with the provided configuration.
  AccountingAgentShell({required AccountingAgentShellConfig config})
      : _config = config;

  final AccountingAgentShellConfig _config;

  /// Starts the agent shell and blocks until the user exits the session.
  Future<void> run() async {
    print(_config.introTitle);
    if (_config.introDescription.isNotEmpty) {
      print(_config.introDescription);
    }
    print('=' * 70);

    final apiKey = Platform.environment['DEEPSEEK_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      print(
        '❌ DEEPSEEK_API_KEY is not set. Export it to use the AI accountant.',
      );
      return;
    }

    final mcpConfigPath =
        path.join(Directory.current.path, 'config', 'mcp_servers.json');
    final mcpConfig = File(mcpConfigPath);
    if (!mcpConfig.existsSync()) {
      print(
        '❌ MCP configuration not found at $mcpConfigPath. Cannot launch agent.',
      );
      return;
    }

    final client = ApiClient(
      baseUrl: 'https://api.deepseek.com/v1',
      apiKey: apiKey,
    );

    final registry = McpToolExecutorRegistry(mcpConfig: mcpConfig);
    await registry.initialize();
    print('✅ MCP servers initialized successfully');

    try {
      final chart = await _loadChartOfAccounts();
      print('✅ Chart of accounts loaded (${chart.length} accounts)');

      final systemPrompt = _buildSystemPrompt(chart);

      final agent = Agent(
        apiClient: client,
        toolRegistry: registry,
        systemPrompt: systemPrompt,
      )..temperature = _config.temperature;

      if (_config.initialPrompt != null &&
          _config.initialPrompt!.trim().isNotEmpty) {
        await _runInitialPrompt(agent, _config.initialPrompt!);
      }

      await _runInteractiveLoop(agent);
    } finally {
      print('\n🧹 Shutting down systems...');
      await registry.shutdown();
      await client.close();
      print('✅ Clean shutdown completed');
    }
  }

  Future<List<Map<String, dynamic>>> _loadChartOfAccounts() async {
    final accountsPath =
        path.join(Directory.current.path, 'inputs', 'accounts.json');
    final accountsFile = File(accountsPath);
    if (!accountsFile.existsSync()) {
      throw Exception(
        '❌ Chart of accounts not found at $accountsPath',
      );
    }

    final contents = await accountsFile.readAsString();
    final decoded = jsonDecode(contents) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  String _buildSystemPrompt(List<Map<String, dynamic>> chartOfAccounts) {
    final accountsByType = <String, List<Map<String, dynamic>>>{};
    for (final account in chartOfAccounts) {
      final type = account['type'] as String? ?? 'Unknown';
      accountsByType.putIfAbsent(type, () => []).add(account);
    }

    final chartDescription = accountsByType.entries.map((entry) {
      final accountList = entry.value
          .map(
            (acc) =>
                '    ${acc['code']}: ${acc['name']} ${acc['gst'] == true ? '(GST: ${acc['gstType']})' : '(No GST)'}',
          )
          .join('\n');
      return '  ${entry.key} Accounts:\n$accountList';
    }).join('\n\n');

    final specialBlock = _config.specialInstructions.isEmpty
        ? ''
        : '\n**SPECIAL WORKFLOWS & SHORTCUTS**:\n${_config.specialInstructions.map((e) => '- $e').join('\n')}\n';

    return '''
🏆 ELITE ACCOUNTING AGENT: Transaction Investigation & Resolution Specialist

**MISSION**: You are an expert accounting agent with MCP tool access. Investigate transaction categorization issues, search ledger data, and apply updates with surgical precision.

**CORE CAPABILITIES**:
1. 🔍 TRANSACTION SEARCH — find entries by keyword, amount, supplier, or date
2. 🧠 BUSINESS CONTEXT — understand Rebellion Rum Co and its COGS vs OPEX split
3. 🛠️ ACCOUNT UPDATES — reassign accounts with correct GST handling and supplier tagging
4. 🛡️ AUDIT COMPLIANCE — protect bank accounts (001-099) and preserve the audit trail

**CHART OF ACCOUNTS** (knowledge base):
$chartDescription
$specialBlock
**BUSINESS CONTEXT - REBELLION RUM CO**:
- Craft distillery producing premium rum and spirits
- COGS include fermentables, yeast, barrels, bottles, labels, postage/shipping, and neutral spirits
- Operating expenses cover rent, marketing, staffing, utilities, and compliance costs
- GST registered business (10% GST)
- Bank accounts (001-099) are protected

**ACCOUNT ASSIGNMENT RULES**:
- Staff payments → accounts 311-313
- Raw materials & production inputs → COGS accounts 200-208
- Shipping, MyPost, Australia Post, courier fees → account 208 "Postage"
- Business operations expenses → expense accounts 300-323
- Revenue transactions → revenue accounts 100-102
- Owner transactions → equity accounts 700-701
- Uncertain transactions → use 999 (Uncategorised) temporarily

**GST HANDLING**:
- GST on Income: revenue accounts (auto split to account 506)
- GST on Expenses: most expense/COGS accounts (auto input credit)
- GST Free: wages, bank fees, licenses, excise tax
- BAS Excluded: bank accounts, equity accounts, GST clearing account

**INVESTIGATION WORKFLOW**:
1. Understand the request and identify target transactions
2. Search using the MCP tools (string search, account filters, date filters, etc.)
3. Analyse the context and determine the correct account/supplier
4. Apply updates using MCP tools, explaining GST and account rationale
5. Summarise findings and confirm any changes

Remember: You are an elite accounting professional. Be thorough, cite the tools you used, and show your reasoning before updating transactions.
''';
  }

  Future<void> _runInitialPrompt(Agent agent, String prompt) async {
    print('\n⚙️ Running initial investigation: "$prompt"');
    print('-' * 50);
    try {
      final result = await agent.sendMessage(prompt);
      print(result.content);
      print('-' * 50);
      print('✅ Initial investigation completed.');
    } catch (e) {
      print('❌ Initial investigation failed: $e');
    }
  }

  Future<void> _runInteractiveLoop(Agent agent) async {
    print(_config.sessionIntro);
    print('=' * 70);
    if (_config.samplePrompts.isNotEmpty) {
      print('💡 Sample prompts:');
      for (final sample in _config.samplePrompts) {
        print('  • $sample');
      }
      print('-' * 70);
    }

    while (true) {
      stdout.write('\n${_config.promptLabel}: ');
      final userInput = stdin.readLineSync()?.trim();
      if (userInput == null || userInput.isEmpty) {
        print('⚠️  No input provided. Please enter a prompt.');
        continue;
      }

      if (_config.exitKeywords
          .map((e) => e.toLowerCase())
          .contains(userInput.toLowerCase())) {
        print('👋 Session terminated by user. Goodbye!');
        break;
      }

      print('\n⚡ Processing: "$userInput"');
      print('-' * 50);
      try {
        final result = await agent.sendMessage(userInput);
        print(result.content);
        print('-' * 50);
        print('✅ Investigation completed. Ready for next prompt.');
      } catch (e) {
        print('❌ Investigation failed: $e');
        print('🛡️ System remains stable. Try a different approach.');
      }
    }
  }
}

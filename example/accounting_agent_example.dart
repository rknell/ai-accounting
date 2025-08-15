import "dart:convert";
import "dart:io";

import "package:dart_openai_client/dart_openai_client.dart";

/// 🏆 ACCOUNTING AGENT EXAMPLE: Demonstration of Elite Investigation Capabilities [+1000 XP]
///
/// **DEMONSTRATION VICTORY**: This example shows how to programmatically use
/// the accounting agent for automated transaction investigation and resolution:
/// 1. Automated investigation workflows
/// 2. Batch transaction processing
/// 3. Programmatic account assignment
/// 4. Integration with existing systems
///
/// **USAGE SCENARIOS**:
/// - Automated monthly transaction categorization
/// - Bulk supplier account assignment
/// - Compliance auditing and verification
/// - Integration with external accounting systems
Future<void> main() async {
  print("🏆 ACCOUNTING AGENT EXAMPLE: Automated Investigation Demo");
  print("=" * 70);

  // 🛡️ **ENVIRONMENT VALIDATION**: Ensure API key is available
  final apiKey = Platform.environment['DEEPSEEK_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    print("❌ SKIPPING DEMO: DEEPSEEK_API_KEY is not set");
    print("💡 Set DEEPSEEK_API_KEY environment variable to run this demo");
    return;
  }

  // 🚀 **CLIENT INITIALIZATION**: Setup API client
  final client = ApiClient(
    baseUrl: "https://api.deepseek.com/v1",
    apiKey: apiKey,
  );

  // 📋 **MCP CONFIGURATION**: Load and initialize MCP servers
  final mcpConfig = File("config/mcp_servers.json");
  if (!mcpConfig.existsSync()) {
    print(
        "❌ SKIPPING DEMO: MCP configuration not found at config/mcp_servers.json");
    return;
  }

  final toolRegistry = McpToolExecutorRegistry(mcpConfig: mcpConfig);
  await toolRegistry.initialize();
  print("✅ MCP servers initialized successfully");

  // 📊 **CHART OF ACCOUNTS LOADING**: Load for system context
  final chartOfAccountsData = await _loadChartOfAccounts();
  print("✅ Chart of accounts loaded (${chartOfAccountsData.length} accounts)");

  // 🧠 **SYSTEM PROMPT CONSTRUCTION**: Build comprehensive accounting context
  final systemPrompt = _buildSystemPrompt(chartOfAccountsData);

  // ⚔️ **AGENT INITIALIZATION**: Create elite accounting agent
  final agent = Agent(
    apiClient: client,
    toolRegistry: toolRegistry,
    systemPrompt: systemPrompt,
  )..temperature = 0.3;

  print("✅ Accounting Agent initialized and ready for demo");
  print("=" * 70);

  try {
    // 🎯 **DEMONSTRATION SCENARIOS**: Show various investigation types
    await _runDemoScenarios(agent);
  } finally {
    // 🧹 **CLEANUP PROTOCOL**: Ensure proper shutdown
    print("\n🧹 Shutting down systems...");
    await toolRegistry.shutdown();
    await client.close();
    print("✅ Clean shutdown completed");
  }
}

/// 🎯 **DEMONSTRATION SCENARIOS**: Show agent capabilities
Future<void> _runDemoScenarios(Agent agent) async {
  final scenarios = [
    {
      'title': '🔍 SCENARIO 1: Staff Wage Investigation',
      'prompt':
          'Search for any transactions that might be staff wages or salary payments and show me what you find',
    },
    {
      'title': '📊 SCENARIO 2: Uncategorized Transaction Analysis',
      'prompt':
          'Find all transactions currently categorized as "Uncategorised" (account 999) and suggest appropriate account assignments',
    },
    {
      'title': '💰 SCENARIO 3: Large Transaction Review',
      'prompt':
          'Show me all transactions over \$500 in the last 3 months and verify their categorization is appropriate',
    },
    {
      'title': '🏭 SCENARIO 4: Business Expense Analysis',
      'prompt':
          'Analyze all expense transactions to identify any that might be miscategorized and suggest corrections',
    },
  ];

  for (final scenario in scenarios) {
    print("\n${scenario['title']}");
    print("-" * 50);
    print("📝 INVESTIGATION: ${scenario['prompt']}");
    print("");

    try {
      // 🧠 **AGENT PROCESSING**: Send investigation to agent
      final result = await agent.sendMessage(scenario['prompt']!);

      // 📊 **RESULTS DISPLAY**: Show investigation results
      print("🏆 RESULTS:");
      print(result.content);

      // ⏱️ **DEMO PACING**: Brief pause between scenarios
      print("\n⏳ Waiting 2 seconds before next scenario...");
      await Future<void>.delayed(Duration(seconds: 2));
    } catch (e) {
      // 💥 **ERROR HANDLING**: Handle investigation failures gracefully
      print("❌ SCENARIO FAILED: $e");
      print("🛡️ Continuing with next scenario...");
    }
  }

  print("\n🎉 DEMONSTRATION COMPLETED!");
  print("💡 Run 'dart run bin/accounting_agent_ui.dart' for interactive mode");
}

/// 📊 **CHART OF ACCOUNTS LOADER**: Load accounting structure
Future<List<Map<String, dynamic>>> _loadChartOfAccounts() async {
  final accountsFile = File("inputs/accounts.json");
  if (!accountsFile.existsSync()) {
    throw Exception(
        "❌ CRITICAL FAILURE: Chart of accounts not found at inputs/accounts.json");
  }

  final accountsJson = await accountsFile.readAsString();
  final accountsList = jsonDecode(accountsJson) as List<dynamic>;

  return accountsList.cast<Map<String, dynamic>>();
}

/// 🧠 **SYSTEM PROMPT BUILDER**: Create comprehensive accounting context
String _buildSystemPrompt(List<Map<String, dynamic>> chartOfAccounts) {
  final accountsByType = <String, List<Map<String, dynamic>>>{};

  // 📋 **ACCOUNT CATEGORIZATION**: Group accounts by type
  for (final account in chartOfAccounts) {
    final type = account['type'] as String;
    accountsByType.putIfAbsent(type, () => []).add(account);
  }

  // 🏗️ **CHART OF ACCOUNTS FORMATTING**: Create readable structure
  final chartDescription = accountsByType.entries.map((entry) {
    final type = entry.key;
    final accounts = entry.value;
    final accountList = accounts
        .map((acc) =>
            "    ${acc['code']}: ${acc['name']} ${acc['gst'] == true ? '(GST: ${acc['gstType']})' : '(No GST)'}")
        .join('\n');

    return "  $type Accounts:\n$accountList";
  }).join('\n\n');

  return """
🏆 ELITE ACCOUNTING AGENT: Transaction Investigation & Resolution Specialist

**MISSION**: You are an expert accounting agent with access to a comprehensive accounting system. Your role is to investigate transaction categorization issues and provide intelligent recommendations.

**CORE CAPABILITIES**:
1. 🔍 **TRANSACTION SEARCH**: Search transactions by string, account, date range, or amount
2. 🔧 **ACCOUNT ANALYSIS**: Analyze transaction patterns and suggest improvements
3. 📊 **BUSINESS INTELLIGENCE**: Apply business context for accurate categorization
4. 🛡️ **AUDIT COMPLIANCE**: Identify compliance issues and categorization problems

**CHART OF ACCOUNTS** (Your Knowledge Base):
$chartDescription

**BUSINESS CONTEXT - REBELLION RUM CO**:
- Craft distillery producing premium rum and spirits
- Revenue from web sales, international sales, and shop sales
- COGS include fermentables, yeast, barrels, bottles, labels, neutral spirits
- Operating expenses include distillery rent, utilities, marketing, staff wages
- GST registered business (10% GST rate)
- Bank accounts (001-099) are PROTECTED and cannot be modified

**INVESTIGATION APPROACH**:
1. **SEARCH**: Use appropriate search tools to find relevant transactions
2. **ANALYZE**: Review transaction details and business context
3. **CATEGORIZE**: Determine correct accounts based on business logic
4. **RECOMMEND**: Suggest account changes with clear reasoning
5. **EXPLAIN**: Provide detailed explanations for all recommendations

**ACCOUNT ASSIGNMENT LOGIC**:
- Staff payments (wages, super, workers comp) → Use accounts 311-313
- Raw materials for rum production → Use COGS accounts 200-206
- Business operations expenses → Use expense accounts 300-323
- Revenue transactions → Use revenue accounts 100-102
- Owner transactions → Use equity accounts 700-701
- Uncertain transactions → Flag for manual review

For demonstration purposes, focus on analysis and recommendations rather than making actual changes.
""";
}

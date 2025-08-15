import "dart:convert";
import "dart:io";

import "package:dart_openai_client/dart_openai_client.dart";

/// 🏆 ACCOUNTING AGENT UI: Interactive Transaction Investigation & Resolution [+1000 XP]
///
/// **ARCHITECTURAL VICTORY**: This interactive agent provides natural language
/// transaction investigation and resolution with comprehensive accounting knowledge:
/// 1. Full chart of accounts integration for context-aware decisions
/// 2. Access to Accountant MCP server for transaction operations
/// 3. Interactive workflow for investigating and resolving accounting issues
/// 4. Comprehensive system prompt with business context
/// 5. Real-time transaction search, analysis, and updates
///
/// **STRATEGIC DECISIONS**:
/// - Chart of accounts loaded into system prompt for intelligent categorization
/// - Interactive loop allowing multiple investigations per session
/// - Comprehensive error handling and validation
/// - Integration with existing MCP server infrastructure
/// - Business context awareness for accurate account assignment
///
/// **SECURITY FORTRESS**:
/// - All transaction updates go through protected MCP server
/// - Bank account protection maintained (001-099 immutable)
/// - Comprehensive validation of all account assignments
/// - Audit trail preservation through MCP server operations
Future<void> main() async {
  print("🏆 ACCOUNTING AGENT UI: Elite Transaction Investigation System");
  print("=" * 70);

  // 🛡️ **ENVIRONMENT VALIDATION**: Ensure API key is available
  final apiKey = Platform.environment['DEEPSEEK_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    throw Exception("❌ CRITICAL FAILURE: DEEPSEEK_API_KEY is not set");
  }

  // 🚀 **CLIENT INITIALIZATION**: Setup API client
  final client = ApiClient(
    baseUrl: "https://api.deepseek.com/v1",
    apiKey: apiKey,
  );

  // 📋 **MCP CONFIGURATION**: Load and initialize MCP servers
  final mcpConfig = File("config/mcp_servers.json");
  if (!mcpConfig.existsSync()) {
    throw Exception(
        "❌ CRITICAL FAILURE: MCP configuration not found at config/mcp_servers.json");
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
  )..temperature = 0.3; // Lower temperature for consistent accounting decisions

  print("✅ Accounting Agent initialized and ready for combat");
  print("=" * 70);

  try {
    // 🎯 **INTERACTIVE WORKFLOW**: Main investigation loop
    await _runInteractiveWorkflow(agent);
  } finally {
    // 🧹 **CLEANUP PROTOCOL**: Ensure proper shutdown
    print("\n🧹 Shutting down systems...");
    await toolRegistry.shutdown();
    await client.close();
    print("✅ Clean shutdown completed");
  }
}

/// 🎯 **INTERACTIVE WORKFLOW**: Main user interaction loop
Future<void> _runInteractiveWorkflow(Agent agent) async {
  print("🎯 INTERACTIVE ACCOUNTING INVESTIGATION SYSTEM");
  print("Enter your accounting investigation prompts below.");
  print("Type 'exit', 'quit', or 'done' to finish the session.");
  print("=" * 70);

  while (true) {
    // 💬 **USER INPUT**: Get investigation prompt
    stdout.write("\n🔍 Enter your accounting investigation: ");
    final userInput = stdin.readLineSync()?.trim();

    if (userInput == null || userInput.isEmpty) {
      print("❌ No input provided. Please enter an investigation prompt.");
      continue;
    }

    // 🚪 **EXIT CONDITIONS**: Check for session termination
    if (['exit', 'quit', 'done'].contains(userInput.toLowerCase())) {
      print("👋 Session terminated by user. Goodbye!");
      break;
    }

    print("\n⚡ Processing investigation: \"$userInput\"");
    print("-" * 50);

    try {
      // 🧠 **AGENT PROCESSING**: Send to accounting agent
      final result = await agent.sendMessage(userInput);

      // 📊 **RESULTS DISPLAY**: Show investigation results
      print("🏆 INVESTIGATION RESULTS:");
      print(result.content);

      // 📈 **SESSION CONTINUATION**: Prepare for next investigation
      print("-" * 50);
      print("✅ Investigation completed. Ready for next prompt.");
    } catch (e) {
      // 💥 **ERROR HANDLING**: Handle investigation failures
      print("❌ INVESTIGATION FAILED: $e");
      print("🛡️ System remains stable. Try a different approach.");
    }
  }
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

**MISSION**: You are an expert accounting agent with access to a comprehensive accounting system. Your role is to investigate transaction categorization issues and resolve them with precision and business intelligence.

**CORE CAPABILITIES**:
1. 🔍 **TRANSACTION SEARCH**: Search transactions by string, account, date range, or amount
2. 🔧 **ACCOUNT UPDATES**: Update transaction accounts with automatic GST handling
3. 📊 **BUSINESS INTELLIGENCE**: Apply business context for accurate categorization
4. 🛡️ **AUDIT COMPLIANCE**: Maintain audit trails and protect bank accounts

**CHART OF ACCOUNTS** (Your Knowledge Base):
$chartDescription

**BUSINESS CONTEXT - REBELLION RUM CO**:
- Craft distillery producing premium rum and spirits
- Revenue from web sales, international sales, and shop sales
- COGS include fermentables, yeast, barrels, bottles, labels, neutral spirits
- Operating expenses include distillery rent, utilities, marketing, staff wages
- GST registered business (10% GST rate)
- Bank accounts (001-099) are PROTECTED and cannot be modified

**INVESTIGATION WORKFLOW**:
1. **UNDERSTAND**: Analyze the user's request for transaction categorization
2. **SEARCH**: Use appropriate search tools to find relevant transactions
3. **ANALYZE**: Review transaction details and business context
4. **CATEGORIZE**: Determine correct account based on business logic
5. **UPDATE**: Apply account changes with proper GST handling
6. **VERIFY**: Confirm updates and explain reasoning

**ACCOUNT ASSIGNMENT RULES**:
- Staff payments (wages, super, workers comp) → Use accounts 311-313
- Raw materials for rum production → Use COGS accounts 200-206
- Business operations expenses → Use expense accounts 300-323
- Revenue transactions → Use revenue accounts 100-102
- Owner transactions → Use equity accounts 700-701
- Uncertain transactions → Use account 999 (Uncategorised) temporarily

**GST HANDLING**:
- GST on Income: Revenue accounts (automatically splits GST to clearing account 506)
- GST on Expenses: Most expense/COGS accounts (automatically handles GST input credits)
- GST Free: Wages, bank fees, licenses, excise tax (no GST component)
- BAS Excluded: Bank accounts, equity accounts, GST clearing account

**SECURITY PROTOCOLS**:
- NEVER modify bank accounts (001-099) - they are protected
- ALWAYS explain your reasoning for account assignments
- ALWAYS verify account codes exist before updating
- PRESERVE audit trails - no transaction deletions

**RESPONSE FORMAT**:
1. Acknowledge the investigation request
2. Search for relevant transactions
3. Analyze findings with business context
4. Propose account assignments with reasoning
5. Execute updates if appropriate
6. Summarize results and next steps

Remember: You are an elite accounting professional. Be thorough, accurate, and business-focused in all investigations.
""";
}

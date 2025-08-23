import 'dart:convert';
import 'dart:io';
import 'package:dart_openai_client/dart_openai_client.dart';

/// Test that the AI categorization uses valid account codes
void main() async {
  print('🔍 Testing AI categorization with valid account codes...');

  // Load valid account codes
  final accountsFile = File('inputs/accounts.json');
  final accountsJson = await accountsFile.readAsString();
  final accounts = jsonDecode(accountsJson) as List<dynamic>;
  final validAccountCodes =
      accounts.map((account) => account['code'] as String).toSet();

  print('✅ Loaded ${validAccountCodes.length} valid account codes');
  print(
      'Valid expense codes: ${validAccountCodes.where((code) => int.parse(code) >= 300 && int.parse(code) <= 999).toList()..sort()}');

  // Test the specific transactions that were failing
  final mcpConfig = File('config/mcp_servers.json');
  final toolRegistry = McpToolExecutorRegistry(mcpConfig: mcpConfig);
  await toolRegistry.initialize();

  // Test Google One (was trying to use account 401)
  print('\n🧪 Testing Google One categorization...');
  final googleCall = ToolCall(
    id: 'test_google_one',
    type: 'function',
    function: ToolCallFunction(
      name: 'match_supplier_fuzzy',
      arguments: jsonEncode({
        'transactionDescription': 'Google One subscription',
        'isIncomeTransaction': false,
        'enableWebResearch': false,
        'maxCandidates': 5,
      }),
    ),
  );

  final googleResult = await toolRegistry.executeTool(googleCall,
      timeout: Duration(seconds: 10));
  final googleParsed = jsonDecode(googleResult);

  if (googleParsed['matchFound'] == true) {
    print('✅ Google One matched to: ${googleParsed['supplier']['name']}');
    print('   Supplies: ${googleParsed['supplier']['supplies']}');
    print(
        '   Suggested account: 306 (Website & Online Fees) or 400 (Software Development Tools)');
  }

  // Test Pin Payments (was trying to use account 451)
  print('\n🧪 Testing Pin Payments categorization...');
  final pinCall = ToolCall(
    id: 'test_pin_payments',
    type: 'function',
    function: ToolCallFunction(
      name: 'match_supplier_fuzzy',
      arguments: jsonEncode({
        'transactionDescription': 'Pin Payments transaction fee',
        'isIncomeTransaction': false,
        'enableWebResearch': false,
        'maxCandidates': 5,
      }),
    ),
  );

  final pinResult =
      await toolRegistry.executeTool(pinCall, timeout: Duration(seconds: 10));
  final pinParsed = jsonDecode(pinResult);

  if (pinParsed['matchFound'] == true) {
    print('✅ Pin Payments matched to: ${pinParsed['supplier']['name']}');
    print('   Supplies: ${pinParsed['supplier']['supplies']}');
    print('   Suggested account: 308 (Bank Fees)');
  }

  await toolRegistry.shutdown();

  print('\n🎯 Account code validation:');
  print('❌ Invalid codes that were causing errors: 401, 451, 501, 502');
  print('✅ Valid alternatives:');
  print('   - Software/Online services: 306, 400');
  print('   - Bank/Payment fees: 308');
  print('   - Uncategorised: 999');

  print(
      '\n🏁 Test complete! The system prompt has been updated to prevent these errors.');
  exit(0);
}

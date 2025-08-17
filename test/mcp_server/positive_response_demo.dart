/// 🎯 **POSITIVE RESPONSE DEMO**: Demonstrate improved AI-friendly responses
///
/// This demo shows how the updated read_supplier tool returns positive,
/// actionable responses instead of "failed" messages that reduce AI confidence.

import 'dart:convert';
import 'dart:io';
import '../../mcp/mcp_server_accountant.dart';

Future<void> main() async {
  print('🎯 POSITIVE RESPONSE DEMO: AI-Friendly Tool Responses');
  print('=' * 60);

  // Setup isolated test environment
  final testDir = Directory('demo_test_data');
  if (testDir.existsSync()) {
    testDir.deleteSync(recursive: true);
  }
  testDir.createSync();
  Directory('demo_test_data/inputs').createSync();
  Directory('demo_test_data/data').createSync();

  final server = AccountantMCPServer(
    enableDebugLogging: false,
    inputsPath: 'demo_test_data/inputs',
    dataPath: 'demo_test_data/data',
    logger: (level, message, [data]) {
      // Suppress debug logs for clean demo output
    },
  );

  await server.initializeServer();

  try {
    print('\n📋 SCENARIO 1: No supplier list exists yet');
    print('-' * 40);

    final result1 = await server.callTool('read_supplier', {
      'supplierName': 'GitHub',
    });

    final data1 = jsonDecode(result1.content.first.text!);
    print('✅ Response: ${data1['message']}');
    print('💡 Suggestion: ${data1['suggestion']}');
    print('🎯 AI sees: success=${data1['success']}, found=${data1['found']}');

    print('\n📋 SCENARIO 2: Supplier list exists but supplier not found');
    print('-' * 40);

    // Create a supplier list with one entry
    await server.callTool('create_supplier', {
      'supplierName': 'Existing Supplier',
      'supplies': 'Known services',
    });

    final result2 = await server.callTool('read_supplier', {
      'supplierName': 'Unknown Supplier',
    });

    final data2 = jsonDecode(result2.content.first.text!);
    print('✅ Response: ${data2['message']}');
    print('💡 Suggestion: ${data2['suggestion']}');
    print('🎯 AI sees: success=${data2['success']}, found=${data2['found']}');

    print('\n📋 SCENARIO 3: Supplier found with fuzzy matching');
    print('-' * 40);

    final result3 = await server.callTool('read_supplier', {
      'supplierName': 'existing supplier', // lowercase, fuzzy match
      'exactMatch': false,
    });

    final data3 = jsonDecode(result3.content.first.text!);
    print('✅ Response: ${data3['message']}');
    print('🔍 Matched: "${data3['searchTerm']}" → "${data3['matchedName']}"');
    print('🎯 AI sees: success=${data3['success']}, found=${data3['found']}');

    print('\n🏆 BENEFITS FOR AI CONFIDENCE:');
    print('-' * 40);
    print('✅ All responses return success=true (no "failed" messages)');
    print('✅ Clear found=true/false flag for easy decision making');
    print('✅ Helpful suggestions guide AI to next actions');
    print('✅ Positive language maintains AI tool confidence');
    print('✅ Actionable messages encourage continued tool usage');

    print('\n🤖 AI DECISION FLOW:');
    print('-' * 40);
    print('1. Call read_supplier tool');
    print('2. Check "found" field in response');
    print('3. If found=true: Use existing supplier data');
    print('4. If found=false: Follow suggestion to research & create');
    print('5. Never sees "failed" - maintains confidence in tools');
  } finally {
    await server.shutdown();

    // Clean up test environment
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  }

  print('\n🎯 Demo completed successfully!');
}

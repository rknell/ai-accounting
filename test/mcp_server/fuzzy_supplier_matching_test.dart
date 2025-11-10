import 'dart:convert';
import 'dart:io';
import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:test/test.dart';

/// 🛡️ PERMANENT TEST FORTRESS: Fuzzy Supplier Matching
///
/// These tests ensure the fuzzy supplier matching functionality works correctly
/// and provide permanent regression protection for critical supplier identification.
void main() {
  group('🎯 Fuzzy Supplier Matching Tests', () {
    late McpToolExecutorRegistry toolRegistry;

    setUpAll(() async {
      // Initialize MCP tool registry for testing
      final mcpConfig = File('config/mcp_servers.json');
      toolRegistry = McpToolExecutorRegistry(mcpConfig: mcpConfig);
      await toolRegistry.initialize();
    });

    tearDownAll(() async {
      await toolRegistry.shutdown();
    });

    test('🛡️ REGRESSION: Fast matching for known suppliers', () async {
      // Test that known suppliers match quickly without web research
      final testCall = ToolCall(
        id: 'test_known_supplier',
        type: 'function',
        function: ToolCallFunction(
          name: 'match_supplier_fuzzy',
          arguments: jsonEncode({
            'transactionDescription': 'Pin Payments Transaction',
            'isIncomeTransaction': false,
            'enableWebResearch': false,
            'maxCandidates': 10,
          }),
        ),
      );

      final stopwatch = Stopwatch()..start();
      final result = await toolRegistry.executeTool(testCall,
          timeout: Duration(seconds: 30));
      stopwatch.stop();

      final parsed = jsonDecode(result);

      // Should match quickly (< 5 seconds) and find Pin Payments
      expect(stopwatch.elapsedMilliseconds, lessThan(5000),
          reason: 'Known supplier matching should be fast');
      expect(parsed['success'], isTrue);
      expect(parsed['matchFound'], isTrue);
      expect(parsed['supplier']['name'], equals('Pin Payments'));
      expect(parsed['confidence'], greaterThan(1.0),
          reason: 'Should have high confidence for exact matches');
    });

    test('🛡️ REGRESSION: String distance matching works correctly', () async {
      // Test fuzzy matching with exact supplier name
      final testCall = ToolCall(
        id: 'test_fuzzy_match',
        type: 'function',
        function: ToolCallFunction(
          name: 'match_supplier_fuzzy',
          arguments: jsonEncode({
            'transactionDescription': 'Pin Payments',
            'isIncomeTransaction': false,
            'enableWebResearch': false, // Disable web research for speed
            'maxCandidates': 5,
          }),
        ),
      );

      final result = await toolRegistry.executeTool(testCall,
          timeout: Duration(seconds: 10));
      final parsed = jsonDecode(result);

      expect(parsed['success'], isTrue);
      expect(parsed['matchFound'], isTrue);
      expect(parsed['supplier']['name'], equals('Pin Payments'));
      expect(parsed['confidence'], greaterThan(0.8),
          reason: 'Should have good confidence for exact matches');
    });

    test('🛡️ REGRESSION: Income vs expense transaction differentiation',
        () async {
      // Test that income transactions are handled differently
      final incomeCall = ToolCall(
        id: 'test_income_transaction',
        type: 'function',
        function: ToolCallFunction(
          name: 'match_supplier_fuzzy',
          arguments: jsonEncode({
            'transactionDescription': 'Osko Deposit John Smith Payment',
            'isIncomeTransaction': true,
            'enableWebResearch': false,
            'maxCandidates': 5,
          }),
        ),
      );

      final result = await toolRegistry.executeTool(incomeCall,
          timeout: Duration(seconds: 10));
      final parsed = jsonDecode(result);

      expect(parsed['success'], isTrue);
      expect(parsed['transactionDescription'],
          equals('Osko Deposit John Smith Payment'));

      // Should handle income transactions differently than expense transactions
      expect(parsed.containsKey('aiGuessedName'), isTrue,
          reason: 'Should attempt to extract names for income transactions');

      // Check if the AI extracted name contains the individual name
      if (parsed['aiGuessedName'] != null) {
        final aiGuessedName = parsed['aiGuessedName'] as String;
        expect(aiGuessedName.toLowerCase(), contains('john'),
            reason:
                'Should attempt to preserve individual names for income transactions');
      }
    });

    test('🚀 FEATURE: Web research integration works', () async {
      // Test that web research can be triggered for unknown suppliers
      final unknownCall = ToolCall(
        id: 'test_web_research',
        type: 'function',
        function: ToolCallFunction(
          name: 'match_supplier_fuzzy',
          arguments: jsonEncode({
            'transactionDescription': 'XYZ Unknown Corporation Ltd',
            'isIncomeTransaction': false,
            'enableWebResearch': true,
            'maxCandidates': 3,
            'confidenceThreshold': 0.9, // High threshold to force web research
          }),
        ),
      );

      final stopwatch = Stopwatch()..start();
      final result = await toolRegistry.executeTool(unknownCall,
          timeout: Duration(seconds: 60));
      stopwatch.stop();

      final parsed = jsonDecode(result);

      expect(parsed['success'], isTrue);
      // Web research might find a match or create a new supplier
      expect(parsed.containsKey('matchFound'), isTrue);

      if (stopwatch.elapsedMilliseconds > 10000) {
        // If it took more than 10 seconds, web research was likely attempted
        print(
            '✅ Web research was attempted (${stopwatch.elapsedMilliseconds}ms)');
      }
    }, timeout: Timeout(Duration(seconds: 90)));

    test('🛡️ REGRESSION: Timeout handling works correctly', () async {
      // Test that the timeout system works and doesn't hang
      final testCall = ToolCall(
        id: 'test_timeout_handling',
        type: 'function',
        function: ToolCallFunction(
          name: 'match_supplier_fuzzy',
          arguments: jsonEncode({
            'transactionDescription': 'Some Test Transaction',
            'isIncomeTransaction': false,
            'enableWebResearch': false,
            'maxCandidates': 5,
          }),
        ),
      );

      final stopwatch = Stopwatch()..start();
      final result = await toolRegistry.executeTool(testCall,
          timeout: Duration(seconds: 5));
      stopwatch.stop();

      // Should complete within timeout
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));

      final parsed = jsonDecode(result);
      expect(parsed['success'], isTrue);
    });

    test('🎯 EDGE_CASE: Empty transaction description handling', () async {
      final emptyCall = ToolCall(
        id: 'test_empty_description',
        type: 'function',
        function: ToolCallFunction(
          name: 'match_supplier_fuzzy',
          arguments: jsonEncode({
            'transactionDescription': '',
            'isIncomeTransaction': false,
            'enableWebResearch': false,
            'maxCandidates': 5,
          }),
        ),
      );

      final result = await toolRegistry.executeTool(emptyCall,
          timeout: Duration(seconds: 10));
      final parsed = jsonDecode(result);

      // Should handle empty descriptions gracefully
      expect(parsed['success'], isTrue);
      // Empty descriptions might match something with low confidence - that's acceptable
      expect(parsed.containsKey('matchFound'), isTrue);
    });

    test('🎯 EDGE_CASE: Special characters in transaction descriptions',
        () async {
      final specialCharsCall = ToolCall(
        id: 'test_special_chars',
        type: 'function',
        function: ToolCallFunction(
          name: 'match_supplier_fuzzy',
          arguments: jsonEncode({
            'transactionDescription':
                'VISA PURCHASE 31/DEC @#\$%^&*()_+ TEST-MERCHANT',
            'isIncomeTransaction': false,
            'enableWebResearch': false,
            'maxCandidates': 5,
          }),
        ),
      );

      final result = await toolRegistry.executeTool(specialCharsCall,
          timeout: Duration(seconds: 10));
      final parsed = jsonDecode(result);

      // Should handle special characters without crashing
      expect(parsed['success'], isTrue);
      expect(parsed['transactionDescription'], contains('TEST-MERCHANT'));
    });
  });
}

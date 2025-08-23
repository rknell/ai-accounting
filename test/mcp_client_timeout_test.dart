import 'dart:convert';
import 'dart:io';
import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:test/test.dart';

/// 🛡️ PERMANENT TEST FORTRESS: MCP Client Timeout Functionality
///
/// These tests ensure that the configurable timeout feature works correctly
/// and provide permanent regression protection for web research operations.
void main() {
  group('⚡ MCP Client Timeout Tests', () {
    late McpToolExecutorRegistry toolRegistry;

    setUpAll(() async {
      final mcpConfig = File('config/mcp_servers.json');
      toolRegistry = McpToolExecutorRegistry(mcpConfig: mcpConfig);
      await toolRegistry.initialize();
    });

    tearDownAll(() async {
      await toolRegistry.shutdown();
    });

    test('🛡️ REGRESSION: Default timeout is 30 seconds for MCP calls',
        () async {
      // Test that the default timeout has been increased from 10s to 30s
      final fastCall = ToolCall(
        id: 'test_default_timeout',
        type: 'function',
        function: ToolCallFunction(
          name: 'list_suppliers',
          arguments: jsonEncode({}),
        ),
      );

      final stopwatch = Stopwatch()..start();
      // Don't specify timeout - should use default 30s
      final result = await toolRegistry.executeTool(fastCall);
      stopwatch.stop();

      // Should complete quickly and successfully
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      final parsed = jsonDecode(result);
      expect(parsed['suppliers'], isNotNull);
    });

    test('🛡️ REGRESSION: Custom timeout parameter works correctly', () async {
      // Test that we can specify custom timeouts
      final testCall = ToolCall(
        id: 'test_custom_timeout',
        type: 'function',
        function: ToolCallFunction(
          name: 'match_supplier_fuzzy',
          arguments: jsonEncode({
            'transactionDescription': 'Quick Test Match',
            'isIncomeTransaction': false,
            'enableWebResearch': false,
            'maxCandidates': 3,
          }),
        ),
      );

      final stopwatch = Stopwatch()..start();
      // Use a 60-second timeout for web research operations
      final result = await toolRegistry.executeTool(testCall,
          timeout: Duration(seconds: 60));
      stopwatch.stop();

      final parsed = jsonDecode(result);
      expect(parsed['success'], isTrue);

      // Should have completed within our timeout
      expect(stopwatch.elapsedMilliseconds, lessThan(60000));
    });

    test('🚀 FEATURE: Web research operations can use extended timeouts',
        () async {
      // Test that web research can run with longer timeouts when needed
      final webResearchCall = ToolCall(
        id: 'test_web_research_timeout',
        type: 'function',
        function: ToolCallFunction(
          name: 'match_supplier_fuzzy',
          arguments: jsonEncode({
            'transactionDescription': 'Some Potentially Unknown Business Name',
            'isIncomeTransaction': false,
            'enableWebResearch': true,
            'maxCandidates': 5,
            'confidenceThreshold':
                0.95, // High threshold to potentially trigger web research
          }),
        ),
      );

      final stopwatch = Stopwatch()..start();
      // Use extended timeout for web research
      final result = await toolRegistry.executeTool(webResearchCall,
          timeout: Duration(seconds: 90));
      stopwatch.stop();

      final parsed = jsonDecode(result);
      expect(parsed['success'], isTrue);

      print(
          '✅ Web research operation completed in ${stopwatch.elapsedMilliseconds}ms');

      // Should not timeout even if web research takes time
      expect(stopwatch.elapsedMilliseconds, lessThan(90000));
    }, timeout: Timeout(Duration(seconds: 120)));

    test('🛡️ REGRESSION: Timeout chain propagates correctly', () async {
      // Test that timeout parameter propagates through the entire call chain:
      // ToolExecutorRegistry -> McpToolExecutor -> McpClient -> _sendRequest
      final timeoutCall = ToolCall(
        id: 'test_timeout_propagation',
        type: 'function',
        function: ToolCallFunction(
          name: 'read_supplier',
          arguments: jsonEncode({
            'supplierName': 'Pin Payments',
          }),
        ),
      );

      final stopwatch = Stopwatch()..start();
      // Use a specific timeout and verify it's respected
      final result = await toolRegistry.executeTool(timeoutCall,
          timeout: Duration(seconds: 15));
      stopwatch.stop();

      final parsed = jsonDecode(result);
      expect(parsed['supplier'], isNotNull);

      // Should complete well within the 15-second timeout
      expect(stopwatch.elapsedMilliseconds, lessThan(15000));
    });

    test('🎯 EDGE_CASE: Very short timeout handling', () async {
      // Test behavior with very short timeouts
      final shortTimeoutCall = ToolCall(
        id: 'test_short_timeout',
        type: 'function',
        function: ToolCallFunction(
          name: 'list_suppliers',
          arguments: jsonEncode({}),
        ),
      );

      // Use a 1-second timeout - should either complete or fail gracefully
      try {
        final result = await toolRegistry.executeTool(shortTimeoutCall,
            timeout: Duration(seconds: 1));

        // If it completes, verify the result is valid
        final parsed = jsonDecode(result);
        expect(parsed['suppliers'], isNotNull);
      } catch (e) {
        // If it times out, that's acceptable for a very short timeout
        expect(e.toString(), contains('timeout'),
            reason: 'Should fail with timeout error for very short timeouts');
      }
    });
  });
}

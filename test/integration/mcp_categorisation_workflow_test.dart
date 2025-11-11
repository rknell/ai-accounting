import 'dart:convert';
import 'dart:io';

import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:test/test.dart';

void main() {
  group('🧭 MCP categorisation workflow', () {
    late McpToolExecutorRegistry toolRegistry;

    setUpAll(() async {
      final configFile = File('config/mcp_servers.json');
      expect(
        configFile.existsSync(),
        isTrue,
        reason: 'MCP configuration file must exist for integration tests',
      );

      toolRegistry = McpToolExecutorRegistry(mcpConfig: configFile);
      await toolRegistry.initialize();
    });

    tearDownAll(() async {
      await toolRegistry.shutdown();
    });

    test('match_supplier_fuzzy returns candidates using accountant server',
        () async {
      final toolCall = ToolCall(
        id: 'integration_match_supplier',
        type: 'function',
        function: ToolCallFunction(
          name: 'match_supplier_fuzzy',
          arguments: jsonEncode({
            'transactionDescription': 'SP GITHUB PAYMENT SYDNEY',
            'isIncomeTransaction': false,
            'enableWebResearch': false,
            'maxCandidates': 5,
          }),
        ),
      );

      final response = await toolRegistry.executeTool(toolCall,
          timeout: Duration(seconds: 30));
      final decoded = jsonDecode(response) as Map<String, dynamic>;

      expect(decoded['success'], isTrue);
      expect(decoded['transactionDescription'], contains('GITHUB'));
      expect(decoded['candidatesConsidered'], greaterThan(0));
      expect(decoded['supplier'], isNotNull,
          reason: 'Accountant server should return supplier data');
    }, timeout: Timeout(Duration(minutes: 2)));

    test('list_suppliers exposes registry data for categorisation checks',
        () async {
      final toolCall = ToolCall(
        id: 'integration_list_suppliers',
        type: 'function',
        function: ToolCallFunction(
          name: 'list_suppliers',
          arguments: jsonEncode({'limit': 3}),
        ),
      );

      final response = await toolRegistry.executeTool(toolCall,
          timeout: Duration(seconds: 15));
      final decoded = jsonDecode(response) as Map<String, dynamic>;
      final suppliers = decoded['suppliers'] as List<dynamic>? ?? [];
      expect(suppliers, isNotEmpty,
          reason:
              'Registry-backed list_suppliers should return existing supplier metadata');
    }, timeout: Timeout(Duration(minutes: 1)));
  });
}

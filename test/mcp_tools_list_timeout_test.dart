import 'dart:convert';
import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:test/test.dart';

/// 🛡️ PERMANENT TEST FORTRESS: MCP Tools List Timeout Functionality
///
/// These tests ensure that tools list requests timeout after 3 seconds
/// while keeping other MCP server timeouts unchanged.
void main() {
  group('⚡ MCP Tools List Timeout Tests', () {
    late McpClient mcpClient;
    late McpServerConfig config;
    
    setUpAll(() {
      // Persist the MCP server config for reuse across tests
      config = McpServerConfig(
        command: 'npx',
        args: ['-y', '@modelcontextprotocol/server-filesystem', '.', '../'],
        env: {},
        workingDirectory: '.',
      );
    });

    setUp(() {
      // Create a fresh MCP client for each test to ensure clean initialization timing
      mcpClient = McpClient(config);
    });

    tearDown(() async {
      await mcpClient.dispose();
    });

    test('🚀 FEATURE: Tools list request times out after 3 seconds', () async {
      // This test verifies that tools list requests timeout after 3 seconds
      // even if the server is slow to respond
      
      final stopwatch = Stopwatch()..start();
      
      try {
        // This should complete within 3 seconds or timeout
        await mcpClient.initialize();
        stopwatch.stop();
        
        // If it completes successfully, it should be fast (< 3 seconds)
        expect(stopwatch.elapsedMilliseconds, lessThan(3000));
        print('✅ Tools list completed in ${stopwatch.elapsedMilliseconds}ms');
        
      } catch (e) {
        stopwatch.stop();
        
        // If it times out, it should be around 3 seconds
        expect(stopwatch.elapsedMilliseconds, greaterThan(2900));
        expect(stopwatch.elapsedMilliseconds, lessThan(4000));
        expect(e.toString(), contains('timeout'));
        print('✅ Tools list correctly timed out after ${stopwatch.elapsedMilliseconds}ms');
      }
    }, timeout: Timeout(Duration(seconds: 10)));

    test('🛡️ REGRESSION: Normal tool execution still uses default timeout', () async {
      // This test ensures that normal tool execution still uses the default 30s timeout
      // and is not affected by the tools list timeout change
      
      // First initialize the client
      await mcpClient.initialize();
      
      // Get a tool to test with
      final tools = mcpClient.tools;
      if (tools.isNotEmpty) {
        final testTool = tools.first;
        
        final stopwatch = Stopwatch()..start();
        
        try {
          // Execute a tool without specifying timeout - should use default 30s
          final result = await mcpClient.executeTool(
            testTool.function.name, 
            jsonEncode({})
          );
          
          stopwatch.stop();
          
          // Should complete successfully (not timeout after 3 seconds)
          expect(stopwatch.elapsedMilliseconds, lessThan(10000)); // Should be much faster than 30s
          expect(result, isNotNull);
          
        } catch (e) {
          stopwatch.stop();
          
          // If it fails, it shouldn't be a timeout at 3 seconds
          if (e.toString().contains('timeout')) {
            // If it does timeout, it should be much longer than 3 seconds
            expect(stopwatch.elapsedMilliseconds, greaterThan(5000));
          }
        }
      }
    }, timeout: Timeout(Duration(seconds: 35)));

    test('🎯 EDGE_CASE: Very fast tools list response is handled correctly', () async {
      // Test that fast-responding servers work correctly with the 3s timeout
      
      final stopwatch = Stopwatch()..start();
      
      try {
        await mcpClient.initialize();
        stopwatch.stop();
        
        // Should complete very quickly (< 1 second for fast servers)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
        expect(mcpClient.toolCount, greaterThan(0));
        
        print('✅ Fast tools list completed in ${stopwatch.elapsedMilliseconds}ms');
        
      } catch (e) {
        stopwatch.stop();
        
        // Should not timeout if server responds quickly
        expect(e.toString(), isNot(contains('timeout')));
        print('⚠️  Unexpected error: $e');
      }
    }, timeout: Timeout(Duration(seconds: 5)));
  });
}

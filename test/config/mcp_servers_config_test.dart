import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('🛡️ REGRESSION: MCP server configuration', () {
    test('accountant server remains registered for categorisation tools', () {
      final projectRoot = Directory.current.path;
      final configPath = path.join(projectRoot, 'config', 'mcp_servers.json');
      final configFile = File(configPath);

      expect(
        configFile.existsSync(),
        isTrue,
        reason: 'MCP server configuration file must exist',
      );

      final configData =
          jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      final servers = (configData['mcpServers'] as Map<String, dynamic>? ?? {});

      expect(
        servers.containsKey('accountant'),
        isTrue,
        reason:
            'Accountant MCP server must remain registered to provide categorisation tools',
      );
    });
  });
}

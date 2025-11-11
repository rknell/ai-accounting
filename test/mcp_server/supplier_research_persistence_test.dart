import 'dart:convert';
import 'dart:io';

import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('✅ Supplier research persistence', () {
    late Directory tempInputsDir;
    late Directory tempDataDir;
    late File tempConfigFile;
    late McpToolExecutorRegistry toolRegistry;

    setUpAll(() async {
      tempInputsDir =
          Directory.systemTemp.createTempSync('ai_accounting_inputs_');
      tempDataDir = Directory.systemTemp.createTempSync('ai_accounting_data_');

      _copyDirectory(Directory('inputs'), tempInputsDir);
      _copyDirectory(Directory('data'), tempDataDir);

      final configMap =
          jsonDecode(File('config/mcp_servers.json').readAsStringSync())
              as Map<String, dynamic>;
      final servers = Map<String, dynamic>.from(
          configMap['mcpServers'] as Map<String, dynamic>);
      final accountantConfig = Map<String, dynamic>.from(
          servers['accountant'] as Map<String, dynamic>);
      final env = Map<String, dynamic>.from(
          accountantConfig['env'] as Map? ?? <String, dynamic>{});
      env['AI_ACCOUNTING_INPUTS_DIR'] = tempInputsDir.path;
      env['AI_ACCOUNTING_DATA_DIR'] = tempDataDir.path;
      env['DEEPSEEK_API_KEY'] =
          Platform.environment['DEEPSEEK_API_KEY'] ?? 'test-api-key';
      accountantConfig['env'] = env;
      servers['accountant'] = accountantConfig;
      configMap['mcpServers'] = servers;

      tempConfigFile =
          File(p.join(tempInputsDir.path, 'mcp_servers_research_test.json'));
      tempConfigFile
          .writeAsStringSync(JsonEncoder.withIndent('  ').convert(configMap));

      toolRegistry = McpToolExecutorRegistry(mcpConfig: tempConfigFile);
      await toolRegistry.initialize();
    });

    tearDownAll(() async {
      await toolRegistry.shutdown();
      if (tempConfigFile.existsSync()) {
        tempConfigFile.deleteSync();
      }
      if (tempInputsDir.existsSync()) {
        tempInputsDir.deleteSync(recursive: true);
      }
      if (tempDataDir.existsSync()) {
        tempDataDir.deleteSync(recursive: true);
      }
    });

    test('🧠 NOTES: raw transaction text becomes alias + boosts future matches',
        () async {
      final supplierName = 'Test Research Alias Supplier';
      final createCall = ToolCall(
        id: 'create_supplier_alias_test',
        type: 'function',
        function: ToolCallFunction(
          name: 'create_supplier',
          arguments: jsonEncode({
            'supplierName': supplierName,
            'supplies': 'AI analytics & research tooling',
            'rawTransactionText': 'SP RESINSIGHTS PTY LTD POS 123',
            'businessDescription':
                'Notes from research: AI analytics platform for bookkeeping data',
          }),
        ),
      );

      final createResult = await toolRegistry.executeTool(
        createCall,
        timeout: Duration(seconds: 30),
      );
      final createParsed = jsonDecode(createResult);

      expect(createParsed['success'], isTrue);

      final supplierFile =
          File(p.join(tempInputsDir.path, 'supplier_list.json'));
      final suppliers = (jsonDecode(supplierFile.readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      final savedSupplier =
          suppliers.firstWhere((entry) => entry['name'] == supplierName);

      final aliases =
          (savedSupplier['aliases'] as List<dynamic>?)?.cast<String>() ?? [];
      expect(aliases, isNotEmpty,
          reason:
              'Alias derived from raw transaction text should be persisted');
      expect(
        aliases.any((alias) => alias.contains('Resinsights')),
        isTrue,
        reason: 'Alias should capture cleaned raw transaction wording',
      );
      expect(savedSupplier['researchNotes'],
          contains('AI analytics platform for bookkeeping'));

      final matchCall = ToolCall(
        id: 'match_supplier_using_alias',
        type: 'function',
        function: ToolCallFunction(
          name: 'match_supplier_fuzzy',
          arguments: jsonEncode({
            'transactionDescription': 'SP RESINSIGHTS PTY LTD POS 123',
            'isIncomeTransaction': false,
            'enableWebResearch': false,
            'maxCandidates': 5,
          }),
        ),
      );

      final matchResult = jsonDecode(await toolRegistry.executeTool(
        matchCall,
        timeout: Duration(seconds: 30),
      ));

      expect(matchResult['success'], isTrue);
      expect(matchResult['matchFound'], isTrue);
      expect(matchResult['supplier']['name'], equals(supplierName));
      expect(matchResult['matchedName'], contains('Resinsights'));
      expect(matchResult['confidence'], greaterThan(0.6));
    }, timeout: Timeout(Duration(minutes: 2)));
  });
}

void _copyDirectory(Directory source, Directory destination) {
  if (!destination.existsSync()) {
    destination.createSync(recursive: true);
  }

  for (final entity in source.listSync(recursive: true)) {
    final relativePath = p.relative(entity.path, from: source.path);
    final newPath = p.join(destination.path, relativePath);
    if (entity is Directory) {
      Directory(newPath).createSync(recursive: true);
    } else if (entity is File) {
      final destinationFile = File(newPath);
      destinationFile.parent.createSync(recursive: true);
      entity.copySync(destinationFile.path);
    }
  }
}

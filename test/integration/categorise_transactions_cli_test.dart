import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('🧪 Categorise transactions CLI smoke test', () {
    late Directory tempDir;
    late Directory tempInputsDir;
    late Directory tempDataDir;

    setUpAll(() {
      tempDir = Directory.systemTemp.createTempSync('categorise_cli_test_');
      tempInputsDir = Directory(p.join(tempDir.path, 'inputs'))
        ..createSync(recursive: true);
      tempDataDir = Directory(p.join(tempDir.path, 'data'))
        ..createSync(recursive: true);

      _copyFile(
          'inputs/accounts.json', p.join(tempInputsDir.path, 'accounts.json'));
      _copyFile('inputs/accounting_rules.txt',
          p.join(tempInputsDir.path, 'accounting_rules.txt'));
      _copyFile('inputs/company_profile.txt',
          p.join(tempInputsDir.path, 'company_profile.txt'));

      final supplierFixture = [
        {
          'name': 'GitHub',
          'supplies': 'Software development tools subscription',
          'account': '400',
          'rawTransactionText': 'SP GITHUB PAYMENT SYDNEY',
          'businessDescription': 'Developer tooling subscriptions',
        },
        {
          'name': 'United Fuel',
          'supplies': 'Fuel and transport services',
          'account': '309',
          'rawTransactionText': 'UNITED FUEL STATION 4210',
          'businessDescription': 'Fuel purchases for delivery vehicles',
        },
      ];
      File(p.join(tempInputsDir.path, 'supplier_list.json')).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(supplierFixture));
    });

    tearDownAll(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        'categorises sample transactions via MCP accountant server and exits cleanly',
        () async {
      final sampleJournal = [
        {
          'date': '2025-01-15',
          'description': 'SP GITHUB PAYMENT SYDNEY',
          'debits': [
            {'accountCode': '999', 'amount': 25.0}
          ],
          'credits': [
            {'accountCode': '001', 'amount': 25.0}
          ],
          'bankBalance': 1000.0,
          'notes': 'Test entry',
        },
        {
          'date': '2025-01-16',
          'description': 'UNITED FUEL STATION 4210',
          'debits': [
            {'accountCode': '999', 'amount': 80.0}
          ],
          'credits': [
            {'accountCode': '001', 'amount': 80.0}
          ],
          'bankBalance': 920.0,
          'notes': 'Test entry 2',
        },
      ];

      File(p.join(tempDataDir.path, 'general_journal.json')).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(sampleJournal));

      final result = await Process.run(
        'dart',
        ['run', 'bin/categorise_transactions.dart'],
        environment: {
          ...Platform.environment,
          'DEEPSEEK_API_KEY':
              Platform.environment['DEEPSEEK_API_KEY'] ?? 'test-api-key',
          'AI_ACCOUNTING_INPUTS_DIR': tempInputsDir.path,
          'AI_ACCOUNTING_DATA_DIR': tempDataDir.path,
        },
      );

      expect(
        result.exitCode,
        equals(0),
        reason:
            'Process stderr:\n${result.stderr}\n--- stdout ---\n${result.stdout}',
      );

      expect(
        result.stdout,
        contains('Categorization complete: 2 transactions processed'),
      );

      final updatedEntries = jsonDecode(
          File(p.join(tempDataDir.path, 'general_journal.json'))
              .readAsStringSync()) as List<dynamic>;

      final containsUncategorisedAccount = updatedEntries.any((entry) {
        final debits = entry['debits'] as List<dynamic>;
        final credits = entry['credits'] as List<dynamic>;
        final debitHas999 =
            debits.any((d) => d['accountCode']?.toString() == '999');
        final creditHas999 =
            credits.any((c) => c['accountCode']?.toString() == '999');
        return debitHas999 || creditHas999;
      });

      expect(containsUncategorisedAccount, isFalse);
    }, timeout: Timeout(Duration(minutes: 3)));
  });
}

void _copyFile(String sourcePath, String destinationPath) {
  final sourceFile = File(sourcePath);
  final destFile = File(destinationPath);
  destFile.parent.createSync(recursive: true);
  sourceFile.copySync(destinationPath);
}

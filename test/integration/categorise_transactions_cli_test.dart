import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

class _FileBackup {
  _FileBackup(this.relativePath)
      : file = File(path.join(Directory.current.path, relativePath)) {
    if (file.existsSync()) {
      _originalContents = file.readAsStringSync();
    } else {
      _originalContents = null;
    }
  }

  final String relativePath;
  final File file;
  String? _originalContents;

  void writeFixture(String contents) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  void restore() {
    if (_originalContents != null) {
      file.writeAsStringSync(_originalContents!);
    } else if (file.existsSync()) {
      file.deleteSync();
    }
  }
}

void main() {
  group('🧪 Categorise transactions CLI smoke test', () {
    late _FileBackup journalBackup;
    late _FileBackup supplierBackup;

    setUp(() {
      journalBackup = _FileBackup('data/general_journal.json');
      supplierBackup = _FileBackup('inputs/supplier_list.json');
    });

    tearDown(() {
      journalBackup.restore();
      supplierBackup.restore();
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

      journalBackup.writeFixture(const JsonEncoder.withIndent('  ').convert(
          sampleJournal));

      final sampleSuppliers = [
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

      supplierBackup.writeFixture(
          const JsonEncoder.withIndent('  ').convert(sampleSuppliers));

      final result = await Process.run(
        'dart',
        ['run', 'bin/categorise_transactions.dart'],
        environment: {
          ...Platform.environment,
          'DEEPSEEK_API_KEY': Platform.environment['DEEPSEEK_API_KEY'] ?? 'test',
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
        reason: 'CLI should report processing the two fixture transactions',
      );

      final updatedEntries =
          jsonDecode(journalBackup.file.readAsStringSync()) as List<dynamic>;

      bool containsUncategorisedAccount() {
        return updatedEntries.any((entry) {
          bool debitHas999 = (entry['debits'] as List<dynamic>)
              .any((d) => d['accountCode'] == '999');
          bool creditHas999 = (entry['credits'] as List<dynamic>)
              .any((c) => c['accountCode'] == '999');
          return debitHas999 || creditHas999;
        });
      }

      expect(
        containsUncategorisedAccount(),
        isFalse,
        reason:
            'Categoriser should reassign account 999 to chart-of-accounts codes',
      );
    }, timeout: Timeout(Duration(minutes: 3)));
  });
}

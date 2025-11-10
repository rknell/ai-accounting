import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/services/bank_statement_service.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('BankStatementService filename mappings', () {
    late Directory tempDir;
    late Directory inputsDir;
    late Directory configDir;
    late ChartOfAccountsService chartService;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('bank_statement_service_test_');
      inputsDir = Directory(p.join(tempDir.path, 'inputs'))
        ..createSync(recursive: true);
      configDir = Directory(p.join(tempDir.path, 'config'))
        ..createSync(recursive: true);

      _writeAccountsFixture(inputsDir);
      chartService = ChartOfAccountsService(
        inputsDirectory: inputsDir.path,
      );

      final getIt = GetIt.instance;
      if (getIt.isRegistered<Services>()) {
        getIt.unregister<Services>();
      }
      getIt.registerSingleton<Services>(_TestServices(chartService));
    });

    tearDown(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<Services>()) {
        getIt.unregister<Services>();
      }
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        '🛡️ REGRESSION: descriptive bank filenames resolve via mapping file to chart codes',
        () {
      _writeMappingFixture(
        configDir,
        {
          'example_bank_statement': '001',
        },
      );

      final csvFile =
          File(p.join(inputsDir.path, 'example_bank_statement.csv'));
      csvFile.writeAsStringSync('Date,Description,Debit,Credit,Balance\n'
          '01/01/2024,Opening balance,100.00,,100.00,\n');

      final service = BankStatementService(
        inputDirectoryPath: inputsDir.path,
        configDirectoryPath: configDir.path,
      );

      final bankFiles = service.loadBankImportFiles();

      expect(bankFiles, hasLength(1));
      expect(bankFiles.single.bankAccountCode, equals('001'));
      expect(bankFiles.single.rawFileRows, hasLength(1));
    });

    test(
        '✅ FEATURE: single file loader accepts explicit bank code for ad-hoc imports',
        () {
      final csvPath = p.join(inputsDir.path, 'custom_statement.csv');
      File(csvPath).writeAsStringSync('Date,Description,Debit,Credit,Balance\n'
          '05/01/2024,Manual Entry,250.00,,750.00,\n');

      final service = BankStatementService(
        inputDirectoryPath: inputsDir.path,
        configDirectoryPath: configDir.path,
      );

      final bankFile =
          service.loadSingleBankImportFile(csvPath, bankAccountCode: '1');

      expect(bankFile, isNotNull);
      expect(bankFile!.bankAccountCode, equals('001'));
      expect(bankFile.rawFileRows.single.description, equals('Manual Entry'));
    });
  });
}

void _writeAccountsFixture(Directory inputsDir) {
  final accountsFile = File(p.join(inputsDir.path, 'accounts.json'));
  accountsFile.writeAsStringSync(jsonEncode([
    {
      '_id': null,
      'code': '001',
      'name': 'Primary Operating Account',
      'type': 'Bank',
      'gst': false,
      'gstType': 'BAS Excluded',
    },
    {
      '_id': null,
      'code': '999',
      'name': 'Uncategorised',
      'type': 'Expense',
      'gst': true,
      'gstType': 'GST on Expenses',
    },
  ]));
}

void _writeMappingFixture(
  Directory configDir,
  Map<String, String> mappings,
) {
  final mappingFile =
      File(p.join(configDir.path, 'bank_account_mappings.json'));
  mappingFile.writeAsStringSync(jsonEncode(mappings));
}

class _TestServices extends Services {
  _TestServices(this._chartService) : super(testMode: true);

  final ChartOfAccountsService _chartService;

  @override
  ChartOfAccountsService get chartOfAccounts => _chartService;
}

import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/split_transaction.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';
import 'package:ai_accounting/services/general_journal_service.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../mcp/mcp_server_accountant.dart';

void main() {
  group('🧭 AI accounting menu tool', () {
    late Directory tempDir;
    late AccountantMCPServer server;
    late _TestServices testServices;
    late String inputsDir;
    late String dataDir;
    late String configDir;

    setUp(() async {
      tempDir =
          Directory.systemTemp.createTempSync('ai_accounting_menu_tool_test_');
      inputsDir = p.join(tempDir.path, 'inputs');
      dataDir = p.join(tempDir.path, 'data');
      configDir = p.join(tempDir.path, 'config');

      Directory(inputsDir).createSync(recursive: true);
      Directory(dataDir).createSync(recursive: true);
      Directory(configDir).createSync(recursive: true);

      _writeAccountsFixture(inputsDir);
      final chartService = ChartOfAccountsService(inputsDirectory: inputsDir);

      final getIt = GetIt.instance;
      if (getIt.isRegistered<Services>()) {
        getIt.unregister<Services>();
      }
      testServices = _TestServices(chartService);
      getIt.registerSingleton<Services>(testServices);

      _writeJournalFixture(dataDir);
      final journalService = GeneralJournalService(
        dataDirectory: dataDir,
      );
      testServices.attachJournal(journalService);

      server = AccountantMCPServer(
        inputsPath: inputsDir,
        dataPath: dataDir,
        enableDebugLogging: true,
      );
      await server.initializeServer();
    });

    tearDown(() async {
      await server.shutdown();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<Services>()) {
        getIt.unregister<Services>();
      }
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('✅ FEATURE: exports transaction summary to requested destination',
        () async {
      final destination = p.join(tempDir.path, 'summary.csv');

      final result = await server.callTool('run_ai_accounting_menu_action', {
        'action': 'export_transaction_summary_csv',
        'destinationPath': destination,
      });

      final payload = jsonDecode(result.content.first.text!);
      expect(payload['success'], isTrue);
      expect(payload['rowCount'], equals(1));

      final csvFile = File(destination);
      expect(csvFile.existsSync(), isTrue);
      final csv = csvFile.readAsStringSync();
      expect(csv, contains('Sample Supplier'));
      expect(csv, contains('Office Supplies'));
    });

    test('✅ FEATURE: mapping updates respect config override directory',
        () async {
      final result = await server.callTool('run_ai_accounting_menu_action', {
        'action': 'update_bank_statement_mapping',
        'mappingFilename': 'statement_jan',
        'bankCode': '1', // Ensure normalization pads to 001
        'configDirectory': configDir,
      });

      final payload = jsonDecode(result.content.first.text!);
      expect(payload['success'], isTrue);
      expect(payload['mappingKey'], equals('statement_jan'));
      expect(payload['bankCode'], equals('001'));

      final mappingFile = File(p.join(configDir, 'bank_account_mappings.json'));
      expect(mappingFile.existsSync(), isTrue);
      final mappings =
          jsonDecode(mappingFile.readAsStringSync()) as Map<String, dynamic>;
      expect(mappings['statement_jan'], equals('001'));
    });
  });
}

void _writeAccountsFixture(String inputsDir) {
  final accountsFile = File(p.join(inputsDir, 'accounts.json'));
  accountsFile.createSync(recursive: true);
  accountsFile.writeAsStringSync(jsonEncode([
    {
      '_id': null,
      'code': '001',
      'name': 'Operating Bank',
      'type': 'Bank',
      'gst': false,
      'gstType': 'BAS Excluded',
    },
    {
      '_id': null,
      'code': '506',
      'name': 'GST Clearing',
      'type': 'Current Liability',
      'gst': false,
      'gstType': 'BAS Excluded',
    },
    {
      '_id': null,
      'code': '610',
      'name': 'Office Supplies',
      'type': 'Expense',
      'gst': true,
      'gstType': 'GST on Expenses',
    },
  ]));
}

void _writeJournalFixture(String dataDir) {
  final file = File(p.join(dataDir, 'general_journal.json'));
  file.createSync(recursive: true);

  final entry = GeneralJournal(
    date: DateTime(2024, 7, 1),
    description: 'Office supplies restock',
    debits: [
      SplitTransaction(accountCode: '610', amount: 110.0),
      SplitTransaction(accountCode: '506', amount: 10.0),
    ],
    credits: [
      SplitTransaction(accountCode: '001', amount: 120.0),
    ],
    bankBalance: 5000.0,
    notes: 'Supplier: Sample Supplier',
  );

  file.writeAsStringSync(jsonEncode([entry.toJson()]));
}

class _TestServices extends Services {
  _TestServices(this._chart) : super(testMode: true);

  final ChartOfAccountsService _chart;
  GeneralJournalService? _journal;

  void attachJournal(GeneralJournalService journal) {
    _journal = journal;
  }

  @override
  ChartOfAccountsService get chartOfAccounts => _chart;

  @override
  GeneralJournalService get generalJournal {
    final journal = _journal;
    if (journal == null) {
      throw StateError('GeneralJournalService not attached');
    }
    return journal;
  }
}

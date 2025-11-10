import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/exporters/general_journal_csv_exporter.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/split_transaction.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('GeneralJournalCsvExporter', () {
    late Directory tempDir;
    late Directory inputsDir;
    late ChartOfAccountsService chartService;
    late _ExporterTestServices services;
    late GeneralJournalCsvExporter exporter;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('general_journal_exporter_test_');
      inputsDir = Directory(p.join(tempDir.path, 'inputs'))
        ..createSync(recursive: true);

      _writeAccountsFixture(inputsDir);
      chartService = ChartOfAccountsService(inputsDirectory: inputsDir.path);
      services = _ExporterTestServices(chartService);
      exporter = GeneralJournalCsvExporter(services);

      final getIt = GetIt.instance;
      if (getIt.isRegistered<Services>()) {
        getIt.unregister<Services>();
      }
      getIt.registerSingleton<Services>(services);
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
        '✅ FEATURE: exporter flattens entries with supplier info and separate debit/credit columns',
        () {
      final entry = GeneralJournal(
        date: DateTime(2024, 7, 1),
        description: 'Visa Purchase, Something',
        debits: [
          SplitTransaction(accountCode: '400', amount: 30.25),
        ],
        credits: [
          SplitTransaction(accountCode: '001', amount: 30.25),
        ],
        bankBalance: 999.0,
        notes:
            'Imported - needs categorization\nSupplier: OpenAI (confidence: 134.3%)',
      );

      final csv = exporter.buildCsv(entries: [entry]);

      expect(
        csv.trim(),
        equals([
          'Date,Description,Supplier,Account Name,Account Code,Credit,Debit',
          '2024-07-01,"Visa Purchase, Something",OpenAI,Software Subscriptions,400,,30.25',
          '2024-07-01,"Visa Purchase, Something",OpenAI,Operating Bank,001,30.25,',
        ].join('\n')),
      );
    });

    test('🎯 EDGE_CASE: exporter leaves supplier blank when notes omit it', () {
      final entry = GeneralJournal(
        date: DateTime(2024, 7, 2),
        description: 'Manual Payment',
        debits: [
          SplitTransaction(accountCode: '400', amount: 25.0),
        ],
        credits: [
          SplitTransaction(accountCode: '001', amount: 25.0),
        ],
        bankBalance: 900.0,
        notes: 'Manual journal entry',
      );

      final csv = exporter.buildCsv(entries: [entry]);

      expect(
        csv.trim(),
        equals([
          'Date,Description,Supplier,Account Name,Account Code,Credit,Debit',
          '2024-07-02,Manual Payment,,Software Subscriptions,400,,25.00',
          '2024-07-02,Manual Payment,,Operating Bank,001,25.00,',
        ].join('\n')),
      );
    });
  });
}

void _writeAccountsFixture(Directory inputsDir) {
  final accountsFile = File(p.join(inputsDir.path, 'accounts.json'));
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
      'code': '400',
      'name': 'Software Subscriptions',
      'type': 'Expense',
      'gst': true,
      'gstType': 'GST on Expenses',
    },
  ]));
}

class _ExporterTestServices extends Services {
  _ExporterTestServices(this._chartService) : super(testMode: true);

  final ChartOfAccountsService _chartService;

  @override
  ChartOfAccountsService get chartOfAccounts => _chartService;
}

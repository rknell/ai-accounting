import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/exporters/transaction_summary_csv_exporter.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/split_transaction.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('TransactionSummaryCsvExporter', () {
    late Directory tempDir;
    late Directory inputsDir;
    late ChartOfAccountsService chartService;
    late _ExporterTestServices services;
    late TransactionSummaryCsvExporter exporter;
    late bool previousValidationState;

    setUp(() {
      previousValidationState = GeneralJournal.disableAccountValidation;
      GeneralJournal.disableAccountValidation = true;

      tempDir =
          Directory.systemTemp.createTempSync('transaction_summary_exporter_');
      inputsDir = Directory(p.join(tempDir.path, 'inputs'))
        ..createSync(recursive: true);

      _writeAccountsFixture(inputsDir);
      chartService = ChartOfAccountsService(inputsDirectory: inputsDir.path);
      services = _ExporterTestServices(chartService);
      exporter = TransactionSummaryCsvExporter(
        services,
        gstClearingAccountCode: '506',
      );
    });

    tearDown(() {
      GeneralJournal.disableAccountValidation = previousValidationState;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        '✅ FEATURE: exporter emits exactly one row per entry excluding bank and GST splits',
        () {
      final entry = GeneralJournal(
        date: DateTime(2024, 7, 3),
        description: 'Office Supplies replenishment',
        debits: [
          SplitTransaction(accountCode: '610', amount: 110.0),
          SplitTransaction(accountCode: '506', amount: 10.0),
        ],
        credits: [
          SplitTransaction(accountCode: '001', amount: 120.0),
        ],
        bankBalance: 750.0,
        notes: 'Supplier: Office Depot (confidence: 93%)',
      );

      final csv = exporter.buildCsv(entries: [entry]);

      expect(
        csv.trim(),
        equals([
          'Date,Description,Supplier,Account Name,Account Code,Credit,Debit',
          '2024-07-03,"Office Supplies replenishment",Office Depot,Office Supplies,610,,110.00',
        ].join('\n')),
      );
    });

    test('🎯 EDGE_CASE: exporter marks entries with only bank/GST splits', () {
      final entry = GeneralJournal(
        date: DateTime(2024, 8, 12),
        description: 'Bank transfer to savings',
        debits: [
          SplitTransaction(accountCode: '002', amount: 500.0),
        ],
        credits: [
          SplitTransaction(accountCode: '001', amount: 500.0),
        ],
        bankBalance: 3000.0,
        notes: 'Internal transfer',
      );

      final csv = exporter.buildCsv(entries: [entry]);

      expect(
        csv.trim(),
        equals([
          'Date,Description,Supplier,Account Name,Account Code,Credit,Debit',
          '2024-08-12,"Bank transfer to savings",,Bank/GST Only Transaction,,,',
        ].join('\n')),
      );
    });

    test('🎯 EDGE_CASE: exporter records income rows through the credit column',
        () {
      final entry = GeneralJournal(
        date: DateTime(2024, 9, 5),
        description: 'Consulting retainer',
        debits: [
          SplitTransaction(accountCode: '001', amount: 1650.0),
        ],
        credits: [
          SplitTransaction(accountCode: '400', amount: 1500.0),
          SplitTransaction(accountCode: '506', amount: 150.0),
        ],
        bankBalance: 9000.0,
        notes: 'Supplier: ACME Corp',
      );

      final csv = exporter.buildCsv(entries: [entry]);

      expect(
        csv.trim(),
        equals([
          'Date,Description,Supplier,Account Name,Account Code,Credit,Debit',
          '2024-09-05,"Consulting retainer",ACME Corp,Software Subscriptions,400,1500.00,',
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
      'code': '002',
      'name': 'Savings Bank',
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
    {
      '_id': null,
      'code': '610',
      'name': 'Office Supplies',
      'type': 'Expense',
      'gst': true,
      'gstType': 'GST on Expenses',
    },
    {
      '_id': null,
      'code': '506',
      'name': 'GST Clearing',
      'type': 'Current Liability',
      'gst': false,
      'gstType': 'BAS Excluded',
    },
  ]));
}

class _ExporterTestServices extends Services {
  _ExporterTestServices(this._chartService) : super(testMode: true);

  final ChartOfAccountsService _chartService;

  @override
  ChartOfAccountsService get chartOfAccounts => _chartService;
}

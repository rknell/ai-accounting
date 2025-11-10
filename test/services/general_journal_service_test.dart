import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/split_transaction.dart';
import 'package:ai_accounting/services/bank_statement_service.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';
import 'package:ai_accounting/services/company_file_service.dart';
import 'package:ai_accounting/services/general_journal_service.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('GeneralJournalService batch persistence', () {
    late Directory tempDir;
    late Directory inputsDir;
    late ChartOfAccountsService chartService;
    late _SpyGeneralJournalService journalService;
    late _TestServices testServices;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('general_journal_service_test_');
      inputsDir = Directory(p.join(tempDir.path, 'inputs'))
        ..createSync(recursive: true);

      _writeAccountsFixture(inputsDir);
      chartService = ChartOfAccountsService(inputsDirectory: inputsDir.path);

      final bankStatementService = _StubBankStatementService();
      final companyFileService = CompanyFileService(testMode: true);
      journalService = _SpyGeneralJournalService(
        companyFileService: companyFileService,
        dataDirectory: tempDir.path,
      );

      testServices = _TestServices(
        chartService: chartService,
        bankStatementService: bankStatementService,
      )..attachJournal(journalService);

      final getIt = GetIt.instance;
      if (getIt.isRegistered<Services>()) {
        getIt.unregister<Services>();
      }
      getIt.registerSingleton<Services>(testServices);

      _seedExistingEntry(journalService);
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

    test('🎯 EDGE_CASE: addEntry can defer persistence until manual save', () {
      final newEntry = GeneralJournal(
        date: DateTime(2024, 2, 1),
        description: 'Batch entry',
        debits: [
          SplitTransaction(accountCode: '999', amount: 120.0),
        ],
        credits: [
          SplitTransaction(accountCode: '001', amount: 120.0),
        ],
        bankBalance: 880.0,
      );

      final wasAdded = journalService.addEntry(newEntry, persist: false);

      expect(wasAdded, isTrue);
      expect(journalService.entries.length, equals(2));
      expect(journalService.saveCount, equals(0),
          reason: 'Persistence should be deferred while batching');

      journalService.saveEntries();
      expect(journalService.saveCount, equals(1));
    });
  });

  group('GeneralJournalService data hygiene', () {
    test('🎯 EDGE_CASE: loadEntries drops non-positive split amounts', () {
      final tempDir =
          Directory.systemTemp.createTempSync('journal_sanitize_test_');
      final dataDir = Directory(p.join(tempDir.path, 'data'))
        ..createSync(recursive: true);
      final journalFile = File(p.join(dataDir.path, 'general_journal.json'));
      journalFile.writeAsStringSync(jsonEncode([
        {
          'date': '2024-03-01T00:00:00.000',
          'description': 'Zero GST adjustment',
          'debits': [
            {'accountCode': '999', 'amount': 0.0},
            {'accountCode': '998', 'amount': -5.0},
          ],
          'credits': [
            {'accountCode': '001', 'amount': 5.0},
          ],
          'bankBalance': 100.0,
          'notes': '',
        }
      ]));

      final service = GeneralJournalService(
        testMode: true,
        companyFileService: CompanyFileService(testMode: true),
        dataDirectory: dataDir.path,
      );

      final previousValidationState = GeneralJournal.disableAccountValidation;
      GeneralJournal.disableAccountValidation = true;
      try {
        expect(service.loadEntries(), isTrue);
      } finally {
        GeneralJournal.disableAccountValidation = previousValidationState;
      }

      expect(service.entries, hasLength(1));
      final entry = service.entries.first;
      expect(entry.debits, hasLength(1));
      expect(entry.debits.first.amount, equals(5.0));
      expect(entry.credits.single.amount, equals(5.0));

      tempDir.deleteSync(recursive: true);
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
      'code': '999',
      'name': 'Uncategorised',
      'type': 'Expense',
      'gst': true,
      'gstType': 'GST on Expenses',
    },
  ]));
}

void _seedExistingEntry(_SpyGeneralJournalService journalService) {
  final entry = GeneralJournal(
    date: DateTime(2024, 1, 1),
    description: 'Seed entry',
    debits: [
      SplitTransaction(accountCode: '999', amount: 100.0),
    ],
    credits: [
      SplitTransaction(accountCode: '001', amount: 100.0),
    ],
    bankBalance: 1000.0,
  );
  journalService.entries.add(entry);
}

class _TestServices extends Services {
  _TestServices({
    required this.chartService,
    required this.bankStatementService,
  }) : super(testMode: true);

  final ChartOfAccountsService chartService;
  final BankStatementService bankStatementService;
  GeneralJournalService? _journalService;

  void attachJournal(GeneralJournalService service) {
    _journalService = service;
  }

  @override
  ChartOfAccountsService get chartOfAccounts => chartService;

  @override
  BankStatementService get bankStatement => bankStatementService;

  @override
  GeneralJournalService get generalJournal {
    final journal = _journalService;
    if (journal == null) {
      throw StateError('GeneralJournalService requested before initialization');
    }
    return journal;
  }
}

class _StubBankStatementService extends BankStatementService {
  _StubBankStatementService() : super(inputDirectoryPath: 'inputs');

  @override
  int countIdenticalEntries(GeneralJournal entry) {
    // Always allow addition (journal count < bank count)
    return 5;
  }
}

class _SpyGeneralJournalService extends GeneralJournalService {
  _SpyGeneralJournalService({
    required CompanyFileService companyFileService,
    required String dataDirectory,
  }) : super(
          testMode: true,
          companyFileService: companyFileService,
          dataDirectory: dataDirectory,
        );

  int saveCount = 0;

  @override
  bool saveEntries() {
    saveCount++;
    return super.saveEntries();
  }
}

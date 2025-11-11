import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/company_file.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/split_transaction.dart';
import 'package:ai_accounting/models/supplier.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';
import 'package:ai_accounting/services/company_file_service.dart';
import 'package:ai_accounting/services/general_journal_service.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Company-file backed services', () {
    late Directory tempDir;
    late File companyFilePath;
    late CompanyFileService companyFileService;
    late ChartOfAccountsService chartService;
    late GeneralJournalService journalService;
    late _TestServices testServices;

    setUp(() {
      tempDir =
          Directory.systemTemp.createTempSync('ai_accounting_company_file_');
      companyFilePath = File(p.join(tempDir.path, 'company_file.json'));

      final sampleAccounts = [
        const Account(
          code: '001',
          name: 'Test Bank',
          type: AccountType.bank,
          gst: false,
          gstType: GstType.basExcluded,
        ),
        const Account(
          code: '316',
          name: 'Office Supplies',
          type: AccountType.expense,
          gst: true,
          gstType: GstType.gstOnExpenses,
        ),
      ];

      final companyData = _buildCompanyFile(accounts: sampleAccounts);
      companyFilePath.writeAsStringSync(jsonEncode(companyData.toJson()));

      companyFileService = CompanyFileService();
      expect(
        companyFileService.ensureCompanyFileReady(
            filePath: companyFilePath.path),
        isTrue,
      );

      chartService = ChartOfAccountsService(
        inputsDirectory: tempDir.path,
        companyFileService: companyFileService,
      );

      testServices = _TestServices(
        chartService: chartService,
        companyFileService: companyFileService,
      );

      final getIt = GetIt.instance;
      if (getIt.isRegistered<Services>()) {
        getIt.unregister<Services>();
      }
      getIt.registerSingleton<Services>(testServices);

      journalService = GeneralJournalService(
        companyFileService: companyFileService,
        dataDirectory: tempDir.path,
      );
      testServices.attachJournal(journalService);
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

    test('ChartOfAccountsService prefers the unified company file snapshot',
        () {
      expect(chartService.loadAccounts(), isTrue);
      final bankAccount = chartService.getAccount('001');
      final expenseAccount = chartService.getAccount('316');

      expect(bankAccount, isNotNull);
      expect(bankAccount!.name, equals('Test Bank'));
      expect(expenseAccount, isNotNull);
      expect(expenseAccount!.name, equals('Office Supplies'));

      final accountsJsonPath = p.join(tempDir.path, 'accounts.json');
      expect(File(accountsJsonPath).existsSync(), isFalse,
          reason:
              'Service should not require legacy accounts.json when company file is loaded');
    });

    test('GeneralJournalService persists entries back to the company file', () {
      expect(journalService.entries, isEmpty);

      final entry = GeneralJournal(
        date: DateTime(2024, 1, 1),
        description: 'Test purchase',
        debits: [
          SplitTransaction(accountCode: '316', amount: 150.0),
        ],
        credits: [
          SplitTransaction(accountCode: '001', amount: 150.0),
        ],
        bankBalance: 850.0,
        notes: 'Unit test entry',
      );

      journalService.entries.add(entry);
      expect(journalService.saveEntries(), isTrue);

      final savedFile = CompanyFile.fromJson(
        jsonDecode(companyFilePath.readAsStringSync()) as Map<String, dynamic>,
      );

      expect(savedFile.generalJournal.length, equals(1));
      expect(
          savedFile.generalJournal.first.description, equals('Test purchase'));
    });
  });
}

CompanyFile _buildCompanyFile({
  required List<Account> accounts,
  List<GeneralJournal> generalJournal = const [],
}) {
  return CompanyFile(
    id: 'company_test',
    profile: const CompanyProfile(
      name: 'Test Co',
      industry: 'Software',
      location: 'Test City',
      founder: 'QA Team',
      mission: 'Quality first',
      products: ['Automation'],
      keyPurchases: ['Data'],
      sustainabilityPractices: [],
      communityValues: [],
      uniqueSellingPoints: [],
      accountingConsiderations: [],
    ),
    accounts: accounts,
    generalJournal: generalJournal,
    accountingRules: const <AccountingRule>[],
    suppliers: const <SupplierModel>[],
    supplierSpendTypes: const [],
    metadata: CompanyFileMetadata(
      version: '1.0.0',
      createdAt: DateTime.utc(2024, 1, 1),
      modifiedAt: DateTime.utc(2024, 1, 1),
      fileSize: 0,
      checksum: 'test',
    ),
  );
}

class _TestServices extends Services {
  _TestServices({
    required this.chartService,
    required this.companyFileService,
  }) : super(testMode: true);

  final ChartOfAccountsService chartService;
  final CompanyFileService companyFileService;
  GeneralJournalService? _journalService;

  void attachJournal(GeneralJournalService service) {
    _journalService = service;
  }

  @override
  ChartOfAccountsService get chartOfAccounts => chartService;

  @override
  CompanyFileService get companyFile => companyFileService;

  @override
  GeneralJournalService get generalJournal {
    final journal = _journalService;
    if (journal == null) {
      throw StateError('GeneralJournalService requested before initialization');
    }
    return journal;
  }
}

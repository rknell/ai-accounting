import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/split_transaction.dart';
import 'package:ai_accounting/models/supplier_spend_type.dart';
import 'package:ai_accounting/reports/supplier_spend_type_report.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:ai_accounting/services/supplier_spend_type_service.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('✅ FEATURE: SupplierSpendTypeReport', () {
    late Directory tempDir;
    late SupplierSpendTypeService spendService;
    late SupplierSpendTypeReport report;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync();
      final mappingFile =
          File(p.join(tempDir.path, 'supplier_spend_types.json'));
      mappingFile.writeAsStringSync(jsonEncode([
        {'supplier': 'Bunnings', 'type': 'one_time'},
        {'supplier': 'Rent', 'type': 'fixed'},
        {'supplier': 'Oji', 'type': 'variable'},
      ]));

      spendService = SupplierSpendTypeService(configDirectory: tempDir.path);
      report = SupplierSpendTypeReport(
        services: Services(testMode: true),
        spendTypeService: spendService,
      );

      GeneralJournal.disableAccountValidation = true;
    });

    tearDown(() {
      GeneralJournal.disableAccountValidation = false;
      tempDir.delete(recursive: true);
    });

    test('🎯 buildBreakdown groups entries by configured supplier type', () {
      final entries = [
        _entry(
          notes: 'Supplier: Bunnings (confidence: 98%)',
          amount: 120,
        ),
        _entry(
          notes: 'Supplier: Rent',
          amount: 950,
        ),
        _entry(
          description: 'Packaging order from Oji',
          amount: 410,
        ),
        _entry(
          description: 'Unknown vendor',
          amount: 75,
        ),
      ];

      final breakdown = report.buildBreakdown(entries);

      expect(
        breakdown.buckets[SupplierSpendType.oneTime]!.transactionCount,
        equals(1),
      );
      expect(
        breakdown.buckets[SupplierSpendType.fixed]!.totalAmount,
        equals(950),
      );
      expect(
        breakdown.buckets[SupplierSpendType.variable]!.totalAmount,
        equals(410),
      );
      expect(breakdown.uncategorized.length, equals(1));
    });
  });
}

GeneralJournal _entry({
  String description = 'Test transaction',
  String notes = '',
  double amount = 100,
}) {
  return GeneralJournal(
    date: DateTime(2024, 3, 1),
    description: description,
    debits: [SplitTransaction(accountCode: '100', amount: amount)],
    credits: [SplitTransaction(accountCode: '200', amount: amount)],
    bankBalance: 0,
    notes: notes,
  );
}

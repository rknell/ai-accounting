import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/services/transaction_categorizer.dart';
import 'package:test/test.dart';

void main() {
  group('🛡️ REGRESSION: Income transaction categorisation', () {
    test('customer payments map to sales revenue account 100', () {
      final result = categorizeIncomeTransaction(
        supplierName: 'Acme Corp',
        suppliesDescription: 'Monthly customer payment',
      );

      expect(result.accountCode, equals('100'));
      expect(
        result.justification,
        contains('customer payment for products or services'),
      );
    });

    test('payment processing suppliers map to other income account 150', () {
      final result = categorizeIncomeTransaction(
        supplierName: 'Stripe',
        suppliesDescription: 'Card processing services',
      );

      expect(result.accountCode, equals('150'));
      expect(result.justification, contains('Processing income'));
    });
  });

  group('🛡️ REGRESSION: Expense transaction categorisation', () {
    test('software subscriptions map to account 400', () {
      final result = categorizeExpenseTransaction(
        supplierName: 'GitHub',
        suppliesDescription: 'Software subscription for developers',
      );

      expect(result.accountCode, equals('400'));
      expect(result.justification, contains('Software and technology'));
    });

    test('grocery suppliers map to ingredients account 206', () {
      final result = categorizeExpenseTransaction(
        supplierName: 'Coles',
        suppliesDescription: 'Grocery ingredients for distillery',
      );

      expect(result.accountCode, equals('206'));
      expect(result.justification, contains('Ingredients'));
    });

    test('marketing spend maps to account 305', () {
      final result = categorizeExpenseTransaction(
        supplierName: 'Rotary Club',
        suppliesDescription: 'Community sponsorship marketing',
      );

      expect(result.accountCode, equals('305'));
      expect(result.justification, contains('Marketing'));
    });

    test('fallback uses office supplies account 316', () {
      final result = categorizeExpenseTransaction(
        supplierName: 'Unknown Supplier',
        suppliesDescription: 'Miscellaneous purchase',
      );

      expect(result.accountCode, equals('316'));
      expect(result.justification, contains('Office Supplies'));
    });
  });

  test('categorizer account codes exist in chart of accounts', () {
    final accountsFile = File('inputs/accounts.json');
    final accountsJson =
        jsonDecode(accountsFile.readAsStringSync()) as List<dynamic>;
    final availableCodes = accountsJson
        .map((entry) => entry['code'] as String)
        .toSet();

    expect(
      availableCodes,
      containsAll(categorizerAccountCodes()),
      reason: 'Every categorizer account code must exist in inputs/accounts.json',
    );
  });
}

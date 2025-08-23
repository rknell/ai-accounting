import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

/// 🛡️ PERMANENT TEST FORTRESS: Account Code Validation
///
/// These tests ensure that the AI only uses valid account codes from the chart of accounts,
/// preventing transaction update failures due to non-existent account codes.
void main() {
  group('🎯 Account Code Validation Tests', () {
    late List<dynamic> accounts;
    late Set<String> validAccountCodes;

    setUpAll(() async {
      // Load the chart of accounts
      final accountsFile = File('inputs/accounts.json');
      final accountsJson = await accountsFile.readAsString();
      accounts = jsonDecode(accountsJson) as List<dynamic>;

      // Extract all valid account codes
      validAccountCodes =
          accounts.map((account) => account['code'] as String).toSet();

      print('✅ Loaded ${validAccountCodes.length} valid account codes');
    });

    test('🛡️ REGRESSION: Chart of accounts contains expected expense accounts',
        () {
      // Verify key expense accounts exist (prevent deletion regression)
      expect(validAccountCodes.contains('300'), isTrue,
          reason: 'Rent - Distillery should exist');
      expect(validAccountCodes.contains('306'), isTrue,
          reason: 'Website & Online Fees should exist');
      expect(validAccountCodes.contains('308'), isTrue,
          reason: 'Bank Fees should exist');
      expect(validAccountCodes.contains('400'), isTrue,
          reason: 'Software Development Tools should exist');
      expect(validAccountCodes.contains('999'), isTrue,
          reason: 'Uncategorised should exist');
    });

    test('🛡️ REGRESSION: Chart of accounts contains expected revenue accounts',
        () {
      // Verify key revenue accounts exist
      expect(validAccountCodes.contains('100'), isTrue,
          reason: 'Web Sales should exist');
      expect(validAccountCodes.contains('101'), isTrue,
          reason: 'International Sales should exist');
    });

    test('🛡️ REGRESSION: Non-existent account codes are not valid', () {
      // Test the specific codes that were causing failures
      expect(validAccountCodes.contains('401'), isFalse,
          reason: 'Account 401 should not exist');
      expect(validAccountCodes.contains('451'), isFalse,
          reason: 'Account 451 should not exist');
      expect(validAccountCodes.contains('501'), isFalse,
          reason: 'Account 501 should not exist');
      expect(validAccountCodes.contains('502'), isFalse,
          reason: 'Account 502 should not exist');
    });

    test('🎯 EDGE_CASE: Account codes are properly formatted', () {
      // Verify all account codes are 3-digit strings
      for (final code in validAccountCodes) {
        expect(code.length, equals(3),
            reason: 'Account code $code should be 3 digits');
        expect(RegExp(r'^\d{3}$').hasMatch(code), isTrue,
            reason: 'Account code $code should be numeric');
      }
    });

    test('🚀 FEATURE: Can identify appropriate accounts for common suppliers',
        () {
      // Test mapping common supplier types to appropriate accounts
      final expenseAccounts =
          accounts.where((account) => account['type'] == 'Expense').toList();

      // Should have accounts for software tools
      final softwareAccounts = expenseAccounts
          .where((account) =>
              account['name'].toString().toLowerCase().contains('software'))
          .toList();
      expect(softwareAccounts.isNotEmpty, isTrue,
          reason: 'Should have accounts for software expenses');

      // Should have accounts for online services
      final onlineAccounts = expenseAccounts
          .where((account) =>
              account['name'].toString().toLowerCase().contains('online') ||
              account['name'].toString().toLowerCase().contains('website'))
          .toList();
      expect(onlineAccounts.isNotEmpty, isTrue,
          reason: 'Should have accounts for online/website expenses');

      // Should have accounts for bank/payment fees
      final bankAccounts = expenseAccounts
          .where((account) =>
              account['name'].toString().toLowerCase().contains('bank') ||
              account['name'].toString().toLowerCase().contains('fee'))
          .toList();
      expect(bankAccounts.isNotEmpty, isTrue,
          reason: 'Should have accounts for bank fees');
    });

    test('🛡️ REGRESSION: Account code ranges are correct', () {
      // Test the ranges mentioned in the system prompt
      final expenseCodes = accounts
          .where((account) => account['type'] == 'Expense')
          .map((account) => account['code'] as String)
          .toList();

      // All expense codes should be in expected ranges (300-324, 400, 999)
      for (final code in expenseCodes) {
        final codeNum = int.parse(code);
        final isInValidRange = (codeNum >= 300 && codeNum <= 324) ||
            codeNum == 400 ||
            codeNum == 999;

        expect(isInValidRange, isTrue,
            reason:
                'Expense account $code should be in range 300-324, 400, or 999');
      }

      final revenueCodes = accounts
          .where((account) => account['type'] == 'Revenue')
          .map((account) => account['code'] as String)
          .toList();

      // All revenue codes should be in 100-200 range
      for (final code in revenueCodes) {
        final codeNum = int.parse(code);
        expect(codeNum >= 100 && codeNum < 300, isTrue,
            reason: 'Revenue account $code should be in range 100-299');
      }
    });
  });
}

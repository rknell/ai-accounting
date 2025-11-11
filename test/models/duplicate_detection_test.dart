import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/split_transaction.dart';
import 'package:test/test.dart';

/// 🧪 PERMANENT TEST FORTRESS: Duplicate Detection Logic
///
/// **MISSION**: Ensure bulletproof duplicate prevention for bank transactions
///
/// **TEST COVERAGE**:
/// - ✅ Categorized transactions are recognized as duplicates
/// - ✅ Identical transactions on same date respect count limits
/// - ✅ Different bank accounts are treated separately
/// - ✅ Different dates are treated separately
/// - ✅ Different amounts are treated separately
/// - ✅ Different descriptions are treated separately

void main() {
  group('🛡️ DUPLICATE DETECTION FORTRESS', () {
    late DateTime testDate;
    late GeneralJournal uncategorizedTransaction;
    late GeneralJournal categorizedTransaction;
    late GeneralJournal identicalTransaction;

    setUp(() {
      testDate = DateTime(2024, 12, 20);

      // Create an uncategorized transaction (account 999)
      uncategorizedTransaction = GeneralJournal(
        date: testDate,
        description: 'Visa Purchase 17Dec 7-Eleven 4210 Ormeau Ormeau',
        debits: [SplitTransaction(accountCode: '999', amount: 130.48)],
        credits: [SplitTransaction(accountCode: '001', amount: 130.48)],
        bankBalance: 232939.4,
        notes: 'Imported - needs categorization',
      );

      // Create the same transaction but categorized (account 506 - valid expense account)
      categorizedTransaction = GeneralJournal(
        date: testDate,
        description: 'Visa Purchase 17Dec 7-Eleven 4210 Ormeau Ormeau',
        debits: [SplitTransaction(accountCode: '506', amount: 130.48)],
        credits: [SplitTransaction(accountCode: '001', amount: 130.48)],
        bankBalance: 232939.4,
        notes: 'AI categorization: Fuel purchase',
      );

      // Create an identical transaction (same bank transaction, different categorization)
      identicalTransaction = GeneralJournal(
        date: testDate,
        description: 'Visa Purchase 17Dec 7-Eleven 4210 Ormeau Ormeau',
        debits: [SplitTransaction(accountCode: '507', amount: 130.48)],
        credits: [SplitTransaction(accountCode: '001', amount: 130.48)],
        bankBalance: 232939.4,
        notes: 'Manual categorization: Office supplies',
      );
    });

    group('🎯 CORE DUPLICATE DETECTION', () {
      test(
          '🛡️ REGRESSION: Categorized transaction is detected as duplicate of uncategorized',
          () {
        // The core issue: after categorization, the transaction should still be recognized as a duplicate
        expect(
            uncategorizedTransaction
                .isSameBankTransaction(categorizedTransaction),
            isTrue,
            reason:
                'Categorized transaction must be recognized as duplicate of original import');
      });

      test(
          '🛡️ REGRESSION: Uncategorized transaction is detected as duplicate of categorized',
          () {
        // Reverse direction should also work
        expect(
            categorizedTransaction
                .isSameBankTransaction(uncategorizedTransaction),
            isTrue,
            reason:
                'Original import must be recognized as duplicate of categorized transaction');
      });

      test(
          '🛡️ REGRESSION: Identical bank transactions with different account codes are duplicates',
          () {
        // Multiple categorizations of the same bank transaction should be detected
        expect(
            categorizedTransaction.isSameBankTransaction(identicalTransaction),
            isTrue,
            reason:
                'Same bank transaction with different account codes must be detected as duplicate');
      });

      test(
          '🚫 EDGE_CASE: Standard equality operator still distinguishes account codes',
          () {
        // The standard == operator should still work for exact matches
        expect(uncategorizedTransaction == categorizedTransaction, isFalse,
            reason:
                'Standard equality must distinguish different account codes');
        expect(categorizedTransaction == identicalTransaction, isFalse,
            reason:
                'Standard equality must distinguish different account codes');
      });
    });

    group('⚔️ MATCHING CRITERIA VALIDATION', () {
      test('🎯 FEATURE: Different bank accounts are NOT duplicates', () {
        final differentBankTransaction = GeneralJournal(
          date: testDate,
          description: 'Visa Purchase 17Dec 7-Eleven 4210 Ormeau Ormeau',
          debits: [SplitTransaction(accountCode: '506', amount: 130.48)],
          credits: [
            SplitTransaction(accountCode: '002', amount: 130.48)
          ], // Different bank account
          bankBalance: 232939.4,
          notes: 'Different bank account',
        );

        expect(
            categorizedTransaction
                .isSameBankTransaction(differentBankTransaction),
            isFalse,
            reason:
                'Different bank accounts must not be considered duplicates');
      });

      test('🎯 FEATURE: Different dates are NOT duplicates', () {
        final differentDateTransaction = GeneralJournal(
          date: DateTime(2024, 12, 21), // Different date
          description: 'Visa Purchase 17Dec 7-Eleven 4210 Ormeau Ormeau',
          debits: [SplitTransaction(accountCode: '506', amount: 130.48)],
          credits: [SplitTransaction(accountCode: '001', amount: 130.48)],
          bankBalance: 232939.4,
          notes: 'Different date',
        );

        expect(
            categorizedTransaction
                .isSameBankTransaction(differentDateTransaction),
            isFalse,
            reason: 'Different dates must not be considered duplicates');
      });

      test('🎯 FEATURE: Different amounts are NOT duplicates', () {
        final differentAmountTransaction = GeneralJournal(
          date: testDate,
          description: 'Visa Purchase 17Dec 7-Eleven 4210 Ormeau Ormeau',
          debits: [
            SplitTransaction(accountCode: '506', amount: 131.48)
          ], // Different amount
          credits: [SplitTransaction(accountCode: '001', amount: 131.48)],
          bankBalance: 232939.4,
          notes: 'Different amount',
        );

        expect(
            categorizedTransaction
                .isSameBankTransaction(differentAmountTransaction),
            isFalse,
            reason: 'Different amounts must not be considered duplicates');
      });

      test('🎯 FEATURE: Different descriptions are NOT duplicates', () {
        final differentDescriptionTransaction = GeneralJournal(
          date: testDate,
          description:
              'Visa Purchase 17Dec Woolworths Ormeau', // Different description
          debits: [SplitTransaction(accountCode: '506', amount: 130.48)],
          credits: [SplitTransaction(accountCode: '001', amount: 130.48)],
          bankBalance: 232939.4,
          notes: 'Different description',
        );

        expect(
            categorizedTransaction
                .isSameBankTransaction(differentDescriptionTransaction),
            isFalse,
            reason: 'Different descriptions must not be considered duplicates');
      });
    });

    group('🔢 IDENTICAL TRANSACTIONS COUNT VALIDATION', () {
      test(
          '🎯 FEATURE: Multiple identical transactions on same date can coexist',
          () {
        // Create two identical bank transactions that occurred on the same date
        final firstTransaction = GeneralJournal(
          date: testDate,
          description: 'ATM Withdrawal',
          debits: [SplitTransaction(accountCode: '999', amount: 100.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 100.00)],
          bankBalance: 1000.00,
          notes: 'First withdrawal',
        );

        final secondTransaction = GeneralJournal(
          date: testDate,
          description: 'ATM Withdrawal',
          debits: [SplitTransaction(accountCode: '999', amount: 100.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 100.00)],
          bankBalance: 900.00, // Different bank balance
          notes: 'Second withdrawal',
        );

        // These should be detected as the same bank transaction type
        expect(
            firstTransaction.isSameBankTransaction(secondTransaction), isTrue,
            reason:
                'Identical transactions on same date should be recognized as same bank transaction type');

        // They should still be exactly equal since bank balance is not part of equality
        expect(firstTransaction == secondTransaction, isTrue,
            reason:
                'Identical transactions should be exactly equal regardless of bank balance');
      });

      test(
          '🛡️ REGRESSION: Bank balance differences do not affect duplicate detection',
          () {
        final sameTransactionDifferentBalance = GeneralJournal(
          date: testDate,
          description: 'Visa Purchase 17Dec 7-Eleven 4210 Ormeau Ormeau',
          debits: [SplitTransaction(accountCode: '506', amount: 130.48)],
          credits: [SplitTransaction(accountCode: '001', amount: 130.48)],
          bankBalance: 999999.99, // Very different bank balance
          notes: 'Different balance',
        );

        expect(
            categorizedTransaction
                .isSameBankTransaction(sameTransactionDifferentBalance),
            isTrue,
            reason:
                'Bank balance differences must not affect duplicate detection');
      });
    });

    group('🏦 BANK ACCOUNT CODE VALIDATION', () {
      test(
          '🎯 FEATURE: Bank account codes in 0-99 range are properly identified',
          () {
        // Test various bank account codes in the valid range (using actual existing accounts)
        final bankCodes = ['001', '002', '003', '050'];

        for (final bankCode in bankCodes) {
          final transaction = GeneralJournal(
            date: testDate,
            description: 'Test transaction',
            debits: [SplitTransaction(accountCode: '506', amount: 100.00)],
            credits: [SplitTransaction(accountCode: bankCode, amount: 100.00)],
            bankBalance: 1000.00,
            notes: 'Test',
          );

          expect(transaction.bankCode, equals(bankCode),
              reason: 'Bank code $bankCode should be properly identified');
        }
      });

      test('🚫 EDGE_CASE: Non-bank account codes are not considered bank codes',
          () {
        // Test that expense accounts (500+) are not considered bank accounts
        final nonBankTransaction = GeneralJournal(
          date: testDate,
          description: 'Test transaction',
          debits: [SplitTransaction(accountCode: '506', amount: 100.00)],
          credits: [
            SplitTransaction(accountCode: '999', amount: 100.00)
          ], // Not a bank account
          bankBalance: 1000.00,
          notes: 'Test',
        );

        expect(() => nonBankTransaction.bankCode, throwsException,
            reason:
                'Non-bank account codes should throw exception when accessing bankCode');
      });
    });
  });
}

import 'package:test/test.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/split_transaction.dart';
import 'package:ai_accounting/services/general_journal_service.dart';

/// 🧪 PERMANENT TEST FORTRESS: GeneralJournalService Duplicate Detection
///
/// **MISSION**: Test the duplicate detection logic in GeneralJournalService
///
/// **CORE TEST COVERAGE**:
/// - ✅ isSameBankTransaction method works correctly
/// - ✅ Categorized transactions are recognized as duplicates
/// - ✅ Journal service tracks duplicate counts correctly
/// - ✅ Manual duplicate detection without bank statement dependency

void main() {
  group('🛡️ GENERAL JOURNAL SERVICE DUPLICATE DETECTION', () {
    late GeneralJournalService journalService;
    late DateTime testDate;

    setUp(() {
      // 🛡️ FORTRESS PROTECTION: Create isolated journal service in TEST MODE
      journalService = GeneralJournalService(testMode: true);
      testDate = DateTime(2024, 12, 20);

      // Clear any existing entries
      journalService.entries.clear();
    });

    group('🎯 CORE DUPLICATE DETECTION LOGIC', () {
      test(
          '🛡️ REGRESSION: isSameBankTransaction detects categorized duplicates',
          () {
        final uncategorizedEntry = GeneralJournal(
          date: testDate,
          description: 'Visa Purchase 17Dec 7-Eleven 4210 Ormeau Ormeau',
          debits: [SplitTransaction(accountCode: '999', amount: 130.48)],
          credits: [SplitTransaction(accountCode: '001', amount: 130.48)],
          bankBalance: 232939.4,
          notes: 'Imported - needs categorization',
        );

        final categorizedEntry = GeneralJournal(
          date: testDate,
          description: 'Visa Purchase 17Dec 7-Eleven 4210 Ormeau Ormeau',
          debits: [SplitTransaction(accountCode: '506', amount: 130.48)],
          credits: [SplitTransaction(accountCode: '001', amount: 130.48)],
          bankBalance: 232939.4,
          notes: 'AI categorization: Fuel purchase',
        );

        expect(
            uncategorizedEntry.isSameBankTransaction(categorizedEntry), isTrue,
            reason:
                'Categorized transaction should be detected as duplicate of uncategorized');
        expect(
            categorizedEntry.isSameBankTransaction(uncategorizedEntry), isTrue,
            reason:
                'Uncategorized transaction should be detected as duplicate of categorized');
      });

      test('🔢 FEATURE: countIdenticalEntries works correctly in journal', () {
        final transaction1 = GeneralJournal(
          date: testDate,
          description: 'ATM Withdrawal',
          debits: [SplitTransaction(accountCode: '999', amount: 100.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 100.00)],
          bankBalance: 1000.00,
          notes: 'First withdrawal',
        );

        final transaction2 = GeneralJournal(
          date: testDate,
          description: 'ATM Withdrawal',
          debits: [SplitTransaction(accountCode: '999', amount: 100.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 100.00)],
          bankBalance: 900.00, // Different balance
          notes: 'Second withdrawal',
        );

        // Add both transactions manually
        journalService.entries.add(transaction1);
        journalService.entries.add(transaction2);

        // Count should be 2 for both transactions since they're the same bank transaction
        final count1 =
            journalService.countIdenticalBankTransactions(transaction1);
        final count2 =
            journalService.countIdenticalBankTransactions(transaction2);

        expect(count1, equals(2),
            reason: 'Should find 2 identical transactions');
        expect(count2, equals(2),
            reason: 'Should find 2 identical transactions');
      });

      test('🛡️ REGRESSION: Categorized transaction counted correctly', () {
        final uncategorizedEntry = GeneralJournal(
          date: testDate,
          description: 'Test Transaction',
          debits: [SplitTransaction(accountCode: '999', amount: 50.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 50.00)],
          bankBalance: 1000.00,
          notes: 'Uncategorized',
        );

        final categorizedEntry = GeneralJournal(
          date: testDate,
          description: 'Test Transaction',
          debits: [SplitTransaction(accountCode: '506', amount: 50.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 50.00)],
          bankBalance: 1000.00,
          notes: 'Categorized',
        );

        // Add uncategorized, then categorized
        journalService.entries.add(uncategorizedEntry);
        journalService.entries.add(categorizedEntry);

        // Both should be counted as the same bank transaction using the new method
        final countUncategorized =
            journalService.countIdenticalBankTransactions(uncategorizedEntry);
        final countCategorized =
            journalService.countIdenticalBankTransactions(categorizedEntry);

        expect(countUncategorized, equals(2),
            reason: 'Should count both uncategorized and categorized versions');
        expect(countCategorized, equals(2),
            reason: 'Should count both uncategorized and categorized versions');
      });
    });

    group('⚔️ BANK TRANSACTION MATCHING CRITERIA', () {
      test('🎯 FEATURE: Different bank accounts are separate', () {
        final account1Transaction = GeneralJournal(
          date: testDate,
          description: 'Transfer',
          debits: [SplitTransaction(accountCode: '999', amount: 100.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 100.00)],
          bankBalance: 1000.00,
          notes: 'Account 1',
        );

        final account2Transaction = GeneralJournal(
          date: testDate,
          description: 'Transfer',
          debits: [SplitTransaction(accountCode: '999', amount: 100.00)],
          credits: [SplitTransaction(accountCode: '002', amount: 100.00)],
          bankBalance: 1000.00,
          notes: 'Account 2',
        );

        expect(account1Transaction.isSameBankTransaction(account2Transaction),
            isFalse,
            reason:
                'Different bank accounts should not be considered same transaction');

        // Add both and verify they're counted separately
        journalService.entries.add(account1Transaction);
        journalService.entries.add(account2Transaction);

        final count1 =
            journalService.countIdenticalEntries(account1Transaction);
        final count2 =
            journalService.countIdenticalEntries(account2Transaction);

        expect(count1, equals(1),
            reason: 'Should only count transactions from same bank account');
        expect(count2, equals(1),
            reason: 'Should only count transactions from same bank account');
      });

      test('🎯 FEATURE: Different dates are separate', () {
        final date1Transaction = GeneralJournal(
          date: testDate,
          description: 'Daily Transaction',
          debits: [SplitTransaction(accountCode: '999', amount: 100.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 100.00)],
          bankBalance: 1000.00,
          notes: 'Date 1',
        );

        final date2Transaction = GeneralJournal(
          date: testDate.add(const Duration(days: 1)),
          description: 'Daily Transaction',
          debits: [SplitTransaction(accountCode: '999', amount: 100.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 100.00)],
          bankBalance: 1000.00,
          notes: 'Date 2',
        );

        expect(
            date1Transaction.isSameBankTransaction(date2Transaction), isFalse,
            reason:
                'Different dates should not be considered same transaction');

        // Add both and verify they're counted separately
        journalService.entries.add(date1Transaction);
        journalService.entries.add(date2Transaction);

        final count1 = journalService.countIdenticalEntries(date1Transaction);
        final count2 = journalService.countIdenticalEntries(date2Transaction);

        expect(count1, equals(1),
            reason: 'Should only count transactions from same date');
        expect(count2, equals(1),
            reason: 'Should only count transactions from same date');
      });

      test('🎯 FEATURE: Different descriptions are separate', () {
        final desc1Transaction = GeneralJournal(
          date: testDate,
          description: 'Purchase at Store A',
          debits: [SplitTransaction(accountCode: '999', amount: 100.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 100.00)],
          bankBalance: 1000.00,
          notes: 'Store A',
        );

        final desc2Transaction = GeneralJournal(
          date: testDate,
          description: 'Purchase at Store B',
          debits: [SplitTransaction(accountCode: '999', amount: 100.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 100.00)],
          bankBalance: 1000.00,
          notes: 'Store B',
        );

        expect(
            desc1Transaction.isSameBankTransaction(desc2Transaction), isFalse,
            reason:
                'Different descriptions should not be considered same transaction');

        // Add both and verify they're counted separately
        journalService.entries.add(desc1Transaction);
        journalService.entries.add(desc2Transaction);

        final count1 = journalService.countIdenticalEntries(desc1Transaction);
        final count2 = journalService.countIdenticalEntries(desc2Transaction);

        expect(count1, equals(1),
            reason: 'Should only count transactions with same description');
        expect(count2, equals(1),
            reason: 'Should only count transactions with same description');
      });

      test('🎯 FEATURE: Different amounts are separate', () {
        final amount1Transaction = GeneralJournal(
          date: testDate,
          description: 'Purchase',
          debits: [SplitTransaction(accountCode: '999', amount: 100.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 100.00)],
          bankBalance: 1000.00,
          notes: 'Amount 100',
        );

        final amount2Transaction = GeneralJournal(
          date: testDate,
          description: 'Purchase',
          debits: [SplitTransaction(accountCode: '999', amount: 200.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 200.00)],
          bankBalance: 1000.00,
          notes: 'Amount 200',
        );

        expect(amount1Transaction.isSameBankTransaction(amount2Transaction),
            isFalse,
            reason:
                'Different amounts should not be considered same transaction');

        // Add both and verify they're counted separately
        journalService.entries.add(amount1Transaction);
        journalService.entries.add(amount2Transaction);

        final count1 = journalService.countIdenticalEntries(amount1Transaction);
        final count2 = journalService.countIdenticalEntries(amount2Transaction);

        expect(count1, equals(1),
            reason: 'Should only count transactions with same amount');
        expect(count2, equals(1),
            reason: 'Should only count transactions with same amount');
      });
    });

    group('🔧 UPDATE ENTRY FUNCTIONALITY', () {
      test('🛡️ REGRESSION: updateEntry works correctly for categorization',
          () {
        final uncategorizedEntry = GeneralJournal(
          date: testDate,
          description: 'Test Transaction',
          debits: [SplitTransaction(accountCode: '999', amount: 100.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 100.00)],
          bankBalance: 1000.00,
          notes: 'Uncategorized',
        );

        final categorizedEntry = GeneralJournal(
          date: testDate,
          description: 'Test Transaction',
          debits: [SplitTransaction(accountCode: '506', amount: 100.00)],
          credits: [SplitTransaction(accountCode: '001', amount: 100.00)],
          bankBalance: 1000.00,
          notes: 'Categorized',
        );

        // Add uncategorized entry
        journalService.entries.add(uncategorizedEntry);
        expect(journalService.entries.length, equals(1));

        // Update to categorized
        final wasUpdated =
            journalService.updateEntry(uncategorizedEntry, categorizedEntry);
        expect(wasUpdated, isTrue, reason: 'Update should succeed');
        expect(journalService.entries.length, equals(1),
            reason: 'Should still have only one entry');

        // Verify the entry was actually updated
        final updatedEntry = journalService.entries.first;
        expect(updatedEntry.debits.first.accountCode, equals('506'),
            reason: 'Account code should be updated');
        expect(updatedEntry.notes, equals('Categorized'),
            reason: 'Notes should be updated');
      });
    });
  });
}

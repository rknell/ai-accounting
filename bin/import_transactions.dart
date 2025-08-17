import 'dart:io';

import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/services/services.dart';

/// 🏆 ELITE TRANSACTION IMPORT SCRIPT
///
/// **MISSION**: Load CSV files from ./inputs directory, match filenames with account codes,
/// and add new transactions to the general journal with bulletproof duplicate detection.
///
/// **ARCHITECTURE**:
/// - Uses existing BankStatementService for CSV parsing and account validation
/// - Leverages GeneralJournalService for duplicate detection and entry management
/// - Follows WARRIOR PROTOCOL: General solutions, comprehensive error handling
///
/// **USAGE**: dart run bin/import_transactions.dart

Future<void> main() async {
  print('🚀 Starting Transaction Import Workflow...');

  try {
    // === INITIALIZATION PHASE ===
    print('📋 Step 1: Initializing services...');
    final services = Services();

    // === STEP 2: LOAD AND VALIDATE CSV FILES ===
    print('📊 Step 2: Loading CSV files from inputs directory...');
    final bankImportFiles = services.bankStatement.loadBankImportFiles();

    if (bankImportFiles.isEmpty) {
      print('⚠️  No valid CSV files found in inputs directory');
      print(
          '💡 Ensure CSV files are named with valid bank account codes (e.g., "110.csv" for account 110)');
      _displayAvailableBankAccounts(services);
      return;
    }

    print('✅ Loaded ${bankImportFiles.length} bank import files:');
    for (final file in bankImportFiles) {
      print(
          '  📄 Account ${file.bankAccountCode}: ${file.rawFileRows.length} transactions');
    }

    // === STEP 3: PROCESS TRANSACTIONS WITH DUPLICATE DETECTION ===
    print('💾 Step 3: Processing transactions with duplicate detection...');

    int totalTransactionsProcessed = 0;
    int newTransactionsAdded = 0;
    int duplicatesSkipped = 0;

    for (final bankFile in bankImportFiles) {
      print('  🏦 Processing account ${bankFile.bankAccountCode}...');

      for (final row in bankFile.rawFileRows) {
        totalTransactionsProcessed++;

        // Set default account code for new transactions (999 = uncategorized)
        if (row.accountCode.isEmpty) {
          row.accountCode = '999'; // UNCATEGORIZED ACCOUNT CODE
          row.reason = 'Imported - needs categorization';
        }

        // Create journal entry from the row
        final journalEntry = GeneralJournal.fromRawFileRow(row);

        // Add to general journal with built-in duplicate checking
        final wasAdded = services.generalJournal.addEntry(journalEntry);

        if (wasAdded) {
          newTransactionsAdded++;
          print(
              '    ➕ Added: ${row.description.substring(0, row.description.length > 50 ? 50 : row.description.length)}... (${row.accountCode})');
        } else {
          duplicatesSkipped++;
        }
      }

      print('  ✅ Account ${bankFile.bankAccountCode} complete');
    }

    // === STEP 4: SUMMARY REPORT ===
    print('\n🏆 IMPORT COMPLETE - VICTORY ACHIEVED!');
    print('📊 BATTLE STATISTICS:');
    print('  🎯 Total transactions processed: $totalTransactionsProcessed');
    print('  ➕ New transactions added: $newTransactionsAdded');
    print('  🛡️ Duplicates prevented: $duplicatesSkipped');
    print(
        '  📈 Success rate: ${((newTransactionsAdded / totalTransactionsProcessed) * 100).toStringAsFixed(1)}%');

    if (newTransactionsAdded > 0) {
      print('\n💡 NEXT STEPS:');
      print(
          '  🤖 Run "dart run bin/run.dart" to categorize uncategorized transactions with AI');
      print('  📊 Check data/general_journal.json for imported entries');
      print('  🌐 Open data/report_viewer.html to view financial reports');
    } else {
      print(
          '\n✨ All transactions were already in the system - no duplicates imported!');
    }
  } catch (e, stackTrace) {
    print('❌ CRITICAL ERROR during import: $e');
    print('🔍 Stack trace: $stackTrace');

    // Provide helpful error context
    if (e.toString().contains('No bank account found')) {
      print(
          '\n💡 SOLUTION: Ensure CSV files are named with valid bank account codes');
      _displayAvailableBankAccounts(Services());
    }

    exit(1);
  }
}

/// 🏦 **BANK ACCOUNT DISPLAY**: Show available bank accounts for filename matching
void _displayAvailableBankAccounts(Services services) {
  try {
    final bankAccounts =
        services.chartOfAccounts.getAccountsByType(AccountType.bank);

    if (bankAccounts.isNotEmpty) {
      print('\n🏦 AVAILABLE BANK ACCOUNTS:');
      for (final account in bankAccounts) {
        print('  📄 ${account.code}.csv -> ${account.name}');
      }
      print(
          '\n📋 EXAMPLE: Name your CSV file "110.csv" if importing for account 110');
    } else {
      print('\n⚠️  No bank accounts found in chart of accounts');
      print('💡 Add bank accounts to inputs/accounts.json first');
    }
  } catch (e) {
    print('⚠️  Could not load chart of accounts: $e');
  }
}

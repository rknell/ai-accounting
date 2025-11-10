import 'dart:io';

import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/bank_import_models.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:path/path.dart' as path;

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
/// **USAGE**:
///   dart run bin/import_transactions.dart
///   dart run bin/import_transactions.dart --file=/path/to/file.csv --bank=001

Future<void> main(List<String> arguments) async {
  final cliArgs = _ImportCliArgs.parse(arguments);
  final targetingSingleFile = cliArgs.filePath != null;
  print('🚀 Starting Transaction Import Workflow...');

  try {
    // === INITIALIZATION PHASE ===
    print('📋 Step 1: Initializing services...');
    final services = Services();

    // === STEP 2: LOAD AND VALIDATE CSV FILES ===
    List<BankImportFile> bankImportFiles;
    if (targetingSingleFile) {
      final targetPath = cliArgs.filePath!;
      print(
          '📊 Step 2: Loading specified file "$targetPath" (${cliArgs.bankAccountCode ?? 'auto bank detection'})...');
      final bankFile = services.bankStatement.loadSingleBankImportFile(
        targetPath,
        bankAccountCode: cliArgs.bankAccountCode,
      );
      if (bankFile == null) {
        print(
            '⚠️  No transactions detected inside "$targetPath". Ensure it contains statement rows.');
        return;
      }
      bankImportFiles = [bankFile];
    } else {
      print('📊 Step 2: Loading CSV files from inputs directory...');
      bankImportFiles = services.bankStatement.loadBankImportFiles();
    }

    if (bankImportFiles.isEmpty) {
      if (targetingSingleFile) {
        print('⚠️  Unable to parse "${cliArgs.filePath}".');
      } else {
        print('⚠️  No valid CSV files found in inputs directory');
        print(
            '💡 Ensure CSV files are named with valid bank account codes (e.g., "110.csv" for account 110)');
        _displayAvailableBankAccounts(services);
      }
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
    bool saveRequired = false;

    for (final bankFile in bankImportFiles) {
      final fileLabel = targetingSingleFile
          ? path.basename(cliArgs.filePath!)
          : 'account ${bankFile.bankAccountCode}';
      print('  🏦 Processing $fileLabel...');

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
        final wasAdded = services.generalJournal.addEntry(
          journalEntry,
          persist: false,
        );

        if (wasAdded) {
          newTransactionsAdded++;
          saveRequired = true;
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
    final successRate = totalTransactionsProcessed == 0
        ? 0
        : (newTransactionsAdded / totalTransactionsProcessed) * 100;
    print('  📈 Success rate: ${successRate.toStringAsFixed(1)}%');

    if (saveRequired) {
      print('\n💾 Saving journal updates once (backup + CSV export)...');
      services.generalJournal.saveEntries();
    }

    if (newTransactionsAdded > 0) {
      print('\n💡 NEXT STEPS:');
      print(
          '  🤖 Run "dart run bin/categorise_transactions.dart" to categorize uncategorized transactions with AI');
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

class _ImportCliArgs {
  final String? filePath;
  final String? bankAccountCode;

  _ImportCliArgs({this.filePath, this.bankAccountCode});

  static _ImportCliArgs parse(List<String> arguments) {
    String? file;
    String? bank;

    for (final arg in arguments) {
      if (arg.startsWith('--file=')) {
        file = arg.substring('--file='.length).trim();
      } else if (arg.startsWith('--bank=')) {
        bank = arg.substring('--bank='.length).trim();
      }
    }

    if (file == null) {
      bank = null; // Ignore bank overrides when no file supplied
    }

    return _ImportCliArgs(
      filePath: (file != null && file.isNotEmpty) ? file : null,
      bankAccountCode: (bank != null && bank.isNotEmpty) ? bank : null,
    );
  }
}

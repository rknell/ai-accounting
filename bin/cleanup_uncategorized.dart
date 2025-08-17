import 'dart:io';

import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/services/services.dart';

/// 💀 ELITE TRANSACTION CLEANUP SCRIPT - NUCLEAR OPTION
///
/// **⚠️ NUCLEAR WARNING: THIS WILL DESTROY DATA! ⚠️**
///
/// **MISSION**: Safely delete all uncategorized transactions (account 999) from the general journal
/// with comprehensive backup and confirmation mechanisms.
///
/// **🛡️ SAFETY PROTOCOLS**:
/// - Automatic backup creation before any deletion
/// - User confirmation prompts for destructive operations
/// - Detailed reporting of what will be deleted
/// - Rollback capability via backup restoration
///
/// **USAGE**: dart run bin/cleanup_uncategorized.dart

const String UNCATEGORIZED_ACCOUNT_CODE = '999';

Future<void> main() async {
  print('💀 NUCLEAR CLEANUP PROTOCOL INITIATED...');
  print(
      '⚠️  WARNING: This script will DELETE uncategorized transactions (account $UNCATEGORIZED_ACCOUNT_CODE)');

  try {
    // === INITIALIZATION PHASE ===
    print('\n📋 Step 1: Initializing services...');
    final services = Services();

    // === STEP 2: SCAN FOR UNCATEGORIZED TRANSACTIONS ===
    print('🔍 Step 2: Scanning for uncategorized transactions...');
    final uncategorizedEntries =
        services.generalJournal.getEntriesByAccount(UNCATEGORIZED_ACCOUNT_CODE);

    if (uncategorizedEntries.isEmpty) {
      print('✨ No uncategorized transactions found - system is clean!');
      print('🏆 MISSION COMPLETE - No action required');
      return;
    }

    // === STEP 3: DISPLAY DESTRUCTION PREVIEW ===
    print('\n💥 DESTRUCTION PREVIEW:');
    print(
        '🎯 Found ${uncategorizedEntries.length} uncategorized transactions to DELETE:');

    double totalAmount = 0.0;
    final dateRange = <DateTime>[];

    for (int i = 0; i < uncategorizedEntries.length && i < 10; i++) {
      final entry = uncategorizedEntries[i];
      totalAmount += entry.amount;
      dateRange.add(entry.date);

      final shortDesc = entry.description.length > 60
          ? '${entry.description.substring(0, 60)}...'
          : entry.description;
      print(
          '  💀 ${entry.date.toIso8601String().substring(0, 10)} | \$${entry.amount.toStringAsFixed(2)} | $shortDesc');
    }

    if (uncategorizedEntries.length > 10) {
      print('  ... and ${uncategorizedEntries.length - 10} more transactions');
    }

    dateRange.sort();
    print('\n📊 DESTRUCTION STATISTICS:');
    print('  💰 Total amount: \$${totalAmount.toStringAsFixed(2)}');
    print(
        '  📅 Date range: ${dateRange.first.toIso8601String().substring(0, 10)} to ${dateRange.last.toIso8601String().substring(0, 10)}');
    print(
        '  🏦 Accounts affected: ${_getAffectedBankAccounts(uncategorizedEntries).join(', ')}');

    // === STEP 4: BACKUP CREATION (MANDATORY) ===
    print('\n🛡️ Step 3: Creating mandatory backup...');
    final backupPath = await _createBackup(services);
    print('✅ Backup created: $backupPath');

    // === STEP 5: DOUBLE CONFIRMATION PROTOCOL ===
    if (!await _getConfirmation(
        '⚠️  CONFIRM DESTRUCTION: Delete ${uncategorizedEntries.length} uncategorized transactions?')) {
      print('🚫 Operation cancelled by user - ABORT MISSION');
      return;
    }

    if (!await _getConfirmation(
        '💀 FINAL CONFIRMATION: This action is IRREVERSIBLE. Continue with deletion?')) {
      print('🚫 Operation cancelled by user - ABORT MISSION');
      return;
    }

    // === STEP 6: EXECUTE DESTRUCTION ===
    print('\n💥 Step 4: Executing transaction deletion...');
    int deletedCount = 0;
    int failedCount = 0;

    for (final entry in uncategorizedEntries) {
      final success = services.generalJournal.removeEntry(entry);
      if (success) {
        deletedCount++;
        if (deletedCount % 10 == 0) {
          print('  🗑️  Deleted $deletedCount transactions...');
        }
      } else {
        failedCount++;
        print('  ❌ Failed to delete: ${entry.description.substring(0, 30)}...');
      }
    }

    // === STEP 7: VICTORY REPORT ===
    print('\n🏆 CLEANUP COMPLETE - DESTRUCTION ACHIEVED!');
    print('💀 DESTRUCTION STATISTICS:');
    print('  ✅ Successfully deleted: $deletedCount transactions');
    print('  ❌ Failed deletions: $failedCount transactions');
    print(
        '  📈 Success rate: ${((deletedCount / uncategorizedEntries.length) * 100).toStringAsFixed(1)}%');

    if (failedCount > 0) {
      print(
          '\n⚠️  Some transactions could not be deleted. Check the general journal manually.');
    }

    print('\n🛡️ SAFETY NET ACTIVATED:');
    print('  📦 Backup location: $backupPath');
    print('  🔄 To restore: copy backup over data/general_journal.json');
    print('  🧪 Verify results: dart run bin/import_transactions.dart');
  } catch (e, stackTrace) {
    print('\n❌ CRITICAL ERROR during cleanup: $e');
    print('🔍 Stack trace: $stackTrace');
    print('\n🛡️ SAFETY MEASURES:');
    print('  📦 Backup should be available in backups/ directory');
    print('  🚨 Do NOT proceed without manual verification');

    exit(1);
  }
}

/// 🛡️ **BACKUP FORTRESS**: Create timestamped backup of general journal
Future<String> _createBackup(Services services) async {
  final timestamp =
      DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
  final backupDir = Directory('backups');

  if (!backupDir.existsSync()) {
    backupDir.createSync(recursive: true);
  }

  final backupPath = 'backups/general_journal_backup_$timestamp.json';
  final originalFile = File('data/general_journal.json');

  if (originalFile.existsSync()) {
    await originalFile.copy(backupPath);
  } else {
    // Create empty backup if original doesn't exist
    File(backupPath).writeAsStringSync('[]');
  }

  return backupPath;
}

/// 🎯 **CONFIRMATION PROTOCOL**: Get user confirmation for destructive operations
Future<bool> _getConfirmation(String message) async {
  print('\n$message');
  print('Type "DESTROY" to confirm, or anything else to cancel:');

  final input = stdin.readLineSync()?.trim();
  return input == 'DESTROY';
}

/// 🏦 **BANK ACCOUNT ANALYZER**: Get list of affected bank accounts
List<String> _getAffectedBankAccounts(List<GeneralJournal> entries) {
  final bankAccounts = <String>{};

  for (final entry in entries) {
    bankAccounts.add(entry.bankCode);
  }

  return bankAccounts.toList()..sort();
}

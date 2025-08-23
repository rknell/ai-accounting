#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/split_transaction.dart';

/// Simple data class to hold journal entry data without validation
class RawJournalEntry {
  final DateTime date;
  final String description;
  final List<SplitTransaction> debits;
  final List<SplitTransaction> credits;
  final double bankBalance;
  final String notes;

  RawJournalEntry({
    required this.date,
    required this.description,
    required this.debits,
    required this.credits,
    required this.bankBalance,
    required this.notes,
  });

  /// Convert to GeneralJournal when accounts are valid
  GeneralJournal toGeneralJournal() {
    return GeneralJournal(
      date: date,
      description: description,
      debits: debits,
      credits: credits,
      bankBalance: bankBalance,
      notes: notes,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'description': description,
      'debits': debits
          .map((d) => {'accountCode': d.accountCode, 'amount': d.amount})
          .toList(),
      'credits': credits
          .map((c) => {'accountCode': c.accountCode, 'amount': c.amount})
          .toList(),
      'bankBalance': bankBalance,
      'notes': notes,
    };
  }
}

/// 🛡️ **JOURNAL ACCOUNT VALIDATOR**: Data integrity enforcement script
///
/// **MISSION**: Scan the general journal and ensure all transactions reference
/// valid accounts that exist in the chart of accounts. Invalid account codes
/// are automatically corrected to "999" (Invalid/Missing Account).
///
/// **STRATEGIC DECISIONS**:
/// - Read-only validation first to report issues
/// - Backup journal before making changes
/// - Fix invalid account codes by setting to "999"
/// - Generate detailed report of all changes made
///
/// **USAGE**: dart run bin/validate_journal_accounts.dart [--fix]
/// - Without --fix: Report validation issues only
/// - With --fix: Actually fix the invalid account codes

void main(List<String> arguments) async {
  final fixMode = arguments.contains('--fix');

  print('🔍 **JOURNAL ACCOUNT VALIDATION PROTOCOL**');
  print(
      'Mode: ${fixMode ? "🔧 FIX MODE - Will correct invalid accounts" : "📋 REPORT MODE - Read-only validation"}');
  print('═══════════════════════════════════════════════════════════════\n');

  try {
    // Load accounts.json directly
    print('📊 **LOADING CHART OF ACCOUNTS**');
    final accountsFile = File('inputs/accounts.json');
    if (!accountsFile.existsSync()) {
      print(
          '💀 **ERROR**: accounts.json file not found at inputs/accounts.json');
      exit(1);
    }

    final accountsJson = jsonDecode(accountsFile.readAsStringSync()) as List;
    final accounts = accountsJson
        .map((json) => Account.fromJson(json as Map<String, dynamic>))
        .toList();
    final validAccountCodes = accounts.map((a) => a.code).toSet();

    print('Total valid account codes: ${validAccountCodes.length}\n');

    // Load general journal directly from JSON
    print('📋 **LOADING GENERAL JOURNAL FROM JSON**');
    final journalFile = File('data/general_journal.json');
    if (!journalFile.existsSync()) {
      print(
          '💀 **ERROR**: general_journal.json file not found at data/general_journal.json');
      exit(1);
    }

    final journalJson = jsonDecode(journalFile.readAsStringSync()) as List;
    final rawJournalEntries = <RawJournalEntry>[];

    // Load entries manually to bypass validation
    for (final json in journalJson) {
      final entry = json as Map<String, dynamic>;
      try {
        // Parse date
        final date = DateTime.parse(entry['date'] as String);
        final description = entry['description'] as String;
        final bankBalance = (entry['bankBalance'] as num).toDouble();
        final notes = entry['notes'] as String? ?? '';

        // Parse debits
        final debitsJson = entry['debits'] as List;
        final debits = debitsJson.map((debitJson) {
          final debit = debitJson as Map<String, dynamic>;
          return SplitTransaction(
            accountCode: debit['accountCode'] as String,
            amount: (debit['amount'] as num).toDouble(),
          );
        }).toList();

        // Parse credits
        final creditsJson = entry['credits'] as List;
        final credits = creditsJson.map((creditJson) {
          final credit = creditJson as Map<String, dynamic>;
          return SplitTransaction(
            accountCode: credit['accountCode'] as String,
            amount: (credit['amount'] as num).toDouble(),
          );
        }).toList();

        // Create RawJournalEntry without validation
        final rawEntry = RawJournalEntry(
          date: date,
          description: description,
          debits: debits,
          credits: credits,
          bankBalance: bankBalance,
          notes: notes,
        );

        rawJournalEntries.add(rawEntry);
      } catch (e) {
        print('⚠️  Skipping malformed entry: ${e.toString()}');
      }
    }

    print('Total journal entries loaded: ${rawJournalEntries.length}\n');

    // Validation phase
    final invalidEntries = <Map<String, dynamic>>[];
    final invalidAccountCodes = <String>{};

    print('🔍 **VALIDATION PHASE**');
    print('Scanning all journal entries for invalid account codes...\n');

    for (int i = 0; i < rawJournalEntries.length; i++) {
      final entry = rawJournalEntries[i];
      final entryInvalid = <String>[];

      // Check debit accounts
      for (final debit in entry.debits) {
        if (!validAccountCodes.contains(debit.accountCode)) {
          entryInvalid.add('DEBIT: ${debit.accountCode}');
          invalidAccountCodes.add(debit.accountCode);
        }
      }

      // Check credit accounts
      for (final credit in entry.credits) {
        if (!validAccountCodes.contains(credit.accountCode)) {
          entryInvalid.add('CREDIT: ${credit.accountCode}');
          invalidAccountCodes.add(credit.accountCode);
        }
      }

      if (entryInvalid.isNotEmpty) {
        // Calculate amount from debits
        final amount =
            entry.debits.fold(0.0, (sum, debit) => sum + debit.amount);

        invalidEntries.add({
          'index': i,
          'date': entry.date,
          'description': entry.description,
          'amount': amount,
          'invalidAccounts': entryInvalid,
        });
      }
    }

    // Report results
    print('📈 **VALIDATION RESULTS**');
    print('═══════════════════════════════════════════════════════════════');
    print('Total entries scanned: ${rawJournalEntries.length}');
    print('Invalid entries found: ${invalidEntries.length}');
    print('Unique invalid account codes: ${invalidAccountCodes.length}');
    print('');

    if (invalidAccountCodes.isNotEmpty) {
      print('🚨 **INVALID ACCOUNT CODES DETECTED**:');
      for (final code in invalidAccountCodes.toList()..sort()) {
        final count = rawJournalEntries
            .expand((e) => [...e.debits, ...e.credits])
            .where((item) => item.accountCode == code)
            .length;
        print('  • $code (used in $count transactions)');
      }
      print('');
    }

    if (invalidEntries.isNotEmpty) {
      print('📋 **DETAILED INVALID ENTRIES**:');
      for (int i = 0; i < invalidEntries.length && i < 10; i++) {
        final entry = invalidEntries[i];
        print('${i + 1}. Entry #${entry['index']} - ${entry['date']}');
        print('   Description: ${entry['description']}');
        print('   Amount: \$${entry['amount']}');
        print('   Invalid accounts: ${entry['invalidAccounts'].join(', ')}');
        print('');
      }

      if (invalidEntries.length > 10) {
        print('   ... and ${invalidEntries.length - 10} more entries\n');
      }
    }

    // Fix phase (if requested)
    if (fixMode && invalidEntries.isNotEmpty) {
      print('🔧 **FIX PHASE INITIATED**');
      print('═══════════════════════════════════════════════════════════════');

      // Create backup first
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final backupPath = 'backups/general_journal_backup_$timestamp.json';

      print('📁 Creating backup: $backupPath');
      final backupDir = Directory('backups');
      if (!backupDir.existsSync()) {
        backupDir.createSync(recursive: true);
      }

      await journalFile.copy(backupPath);
      print('✅ Backup created successfully\n');

      // Check if account 999 exists, if not warn user
      if (!validAccountCodes.contains('999')) {
        print(
            '⚠️  **WARNING**: Account code "999" does not exist in chart of accounts.');
        print(
            '   You should add account 999 (Invalid/Missing Account) to your chart of accounts.');
        print('   Proceeding anyway...\n');
      }

      // Apply fixes by creating new journal entries with corrected accounts
      int fixedCount = 0;
      final fixedEntries = <RawJournalEntry>[];

      for (final entry in rawJournalEntries) {
        bool entryModified = false;

        // Fix debit accounts - create new SplitTransaction objects if needed
        final fixedDebits = <SplitTransaction>[];
        for (final debit in entry.debits) {
          if (!validAccountCodes.contains(debit.accountCode)) {
            print(
                '🔧 Fixing DEBIT account: ${debit.accountCode} → 999 in entry "${entry.description}"');
            fixedDebits.add(
                SplitTransaction(accountCode: '999', amount: debit.amount));
            entryModified = true;
          } else {
            fixedDebits.add(debit);
          }
        }

        // Fix credit accounts - create new SplitTransaction objects if needed
        final fixedCredits = <SplitTransaction>[];
        for (final credit in entry.credits) {
          if (!validAccountCodes.contains(credit.accountCode)) {
            print(
                '🔧 Fixing CREDIT account: ${credit.accountCode} → 999 in entry "${entry.description}"');
            fixedCredits.add(
                SplitTransaction(accountCode: '999', amount: credit.amount));
            entryModified = true;
          } else {
            fixedCredits.add(credit);
          }
        }

        // Create new RawJournalEntry with fixed accounts
        if (entryModified) {
          final fixedEntry = RawJournalEntry(
            date: entry.date,
            description: entry.description,
            debits: fixedDebits,
            credits: fixedCredits,
            bankBalance: entry.bankBalance,
            notes: entry.notes,
          );
          fixedEntries.add(fixedEntry);
          fixedCount++;
        } else {
          fixedEntries.add(entry);
        }
      }

      // Save the fixed journal back to JSON
      print('\n💾 **SAVING FIXED JOURNAL**');
      final fixedJson = fixedEntries.map((entry) => entry.toJson()).toList();
      final jsonEncoder = JsonEncoder.withIndent('  ');
      journalFile.writeAsStringSync(jsonEncoder.convert(fixedJson));

      print('✅ Journal validation and fix completed!');
      print('   Fixed entries: $fixedCount');
      print('   Invalid account codes changed to: 999');
      print('   Original backed up to: $backupPath');
    } else if (invalidEntries.isNotEmpty) {
      print('🔧 **TO FIX THESE ISSUES**:');
      print('Run: dart run bin/validate_journal_accounts.dart --fix');
      print('This will:');
      print('  • Create a backup of the current journal');
      print('  • Change all invalid account codes to "999"');
      print('  • Save the corrected journal');
      print(
          '\n⚠️  Make sure account "999" exists in your chart of accounts first!');
    } else {
      print('🎉 **ALL JOURNAL ENTRIES VALIDATED SUCCESSFULLY**');
      print('No invalid account codes found. Data integrity confirmed!');
    }
  } catch (e, stackTrace) {
    print('💀 **VALIDATION FAILED**');
    print('Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

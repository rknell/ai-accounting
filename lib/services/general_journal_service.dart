import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/bank_import_models.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/split_transaction.dart';
import 'package:ai_accounting/services/environment_service.dart';
import 'package:ai_accounting/services/services.dart';

/// Service that provides access to general journal data
class GeneralJournalService {
  /// List of all general journal entries
  final List<GeneralJournal> entries = [];

  /// Flag indicating if data has been loaded
  bool _isLoaded = false;

  /// Default constructor
  GeneralJournalService() {
    loadEntries();
  }

  /// Loads general journal entries from the JSON file
  ///
  /// Returns true if successful, false otherwise
  bool loadEntries() {
    if (_isLoaded) return true;

    try {
      final file = File('data/general_journal.json');

      // Create the file if it doesn't exist
      if (!file.existsSync()) {
        file.createSync(recursive: true);
        file.writeAsStringSync('[]');
      }

      final jsonString = file.readAsStringSync();
      if (jsonString.isEmpty) {
        _isLoaded = true;
        return true;
      }

      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;

      entries.clear();
      for (final jsonMap in jsonList) {
        final entry = GeneralJournal.fromJson(jsonMap as Map<String, dynamic>);
        entries.add(entry);
      }

      _isLoaded = true;
      return true;
    } catch (e, stackTrace) {
      print('Error loading general journal entries: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Saves general journal entries to the JSON file and exports to CSV
  ///
  /// Returns true if successful, false otherwise
  bool saveEntries() {
    try {
      final file = File('data/general_journal.json');
      // Sort entries in ascending date order before saving
      entries.sort((a, b) => a.date.compareTo(b.date));
      final jsonString = jsonEncode(entries.map((e) => e.toJson()).toList());
      file.writeAsStringSync(jsonString);

      // Export to CSV
      _exportToCsv();

      return true;
    } catch (e) {
      print('Error saving general journal entries: $e');
      return false;
    }
  }

  /// Exports general journal entries to a CSV file
  void _exportToCsv() {
    try {
      final csvFile = File('data/general_journal.csv');
      final buffer = StringBuffer();

      // Write header
      buffer.writeln('Date,Description,Debits,Credits,Notes');

      // Write entries
      for (final entry in entries) {
        buffer.writeln(entry.toCSV());
      }

      csvFile.writeAsStringSync(buffer.toString());
    } catch (e) {
      print('Error exporting general journal to CSV: $e');
    }
  }

  /// Checks if this is the first transaction for a specific bank account
  ///
  /// This method determines whether the provided journal entry is the first transaction
  /// for its associated bank account by checking if any existing entries use the same
  /// bank account code in their debits or credits lists.
  ///
  /// @param entry The general journal entry to check
  /// @return True if this is the first transaction for the bank account, false otherwise
  bool isFirstTransaction(GeneralJournal entry) {
    final bankCode = entry.bankCode;

    // Check if any existing entries involve this bank account
    final isFirst = !entries.any((existingEntry) {
      // Check if bank code exists in any debit or credit transactions
      return existingEntry.debits
              .any((debit) => debit.accountCode == bankCode) ||
          existingEntry.credits.any((credit) => credit.accountCode == bankCode);
    });

    return isFirst;
  }

  /// Creates an opening balance entry for a bank account
  ///
  /// This method creates an opening balance transaction using the owner's equity account code
  /// and the bank account from the provided journal entry. The transaction date is set
  /// to midnight on the same day as the entry.
  void createOpeningBalance(GeneralJournal entry) {
    final openingBalance = entry.bankBalance;
    print(
        'Creating opening balance: $openingBalance for account ${entry.bankAccount.name} (${entry.bankAccount.code})');

    // Set the date to midnight on the day before the entry
    final openingDate =
        DateTime(entry.date.year, entry.date.month, entry.date.day)
            .subtract(const Duration(days: 1));

    var bankAccount = entry.bankAccount;
    final equityAccountCode = environment.ownersEquityAccountCode;

    // Create the opening balance entry with appropriate split transactions
    final openingBalanceEntry = GeneralJournal(
      date: openingDate,
      description: "Opening Balance - ${bankAccount.name}",
      debits: openingBalance > 0
          ? [
              SplitTransaction(
                  accountCode: bankAccount.code, amount: openingBalance.abs())
            ]
          : [
              SplitTransaction(
                  accountCode: equityAccountCode, amount: openingBalance.abs())
            ],
      credits: openingBalance > 0
          ? [
              SplitTransaction(
                  accountCode: equityAccountCode, amount: openingBalance.abs())
            ]
          : [
              SplitTransaction(
                  accountCode: bankAccount.code, amount: openingBalance.abs())
            ],
      bankBalance: openingBalance,
    );

    // Add the opening balance entry and save
    entries.add(openingBalanceEntry);
    saveEntries();
  }

  /// Creates split transactions accounting for GST if applicable
  ///
  /// This method handles the creation of appropriate split transactions for an account,
  /// automatically handling GST calculations if the account is GST inclusive.
  ///
  /// @param accountCode The account code being credited or debited
  /// @param amount The full transaction amount (GST inclusive if applicable)
  /// @param isGstOnIncome Whether this is for GST on income (if false, assumes GST on expenses)
  /// @return A list of SplitTransaction objects
  List<SplitTransaction> _createSplitTransactionsWithGst(
      String accountCode, double amount, bool isGstOnIncome) {
    // Get the account to check if it's GST inclusive
    final account = services.chartOfAccounts.getAccount(accountCode);
    if (account == null) {
      // No valid account found, return a single transaction
      return [SplitTransaction(accountCode: accountCode, amount: amount)];
    }

    // Check if this account is GST inclusive
    if (account.gst) {
      // GST rate is 10%
      final gstRate = 0.1;

      // Calculate the GST component
      // For a GST inclusive amount, the GST is amount * (rate / (1 + rate))
      // For example, for $110 including 10% GST, the GST is $10
      final gstAmount = amount * (gstRate / (1 + gstRate));
      final netAmount = amount - gstAmount;

      // Get GST clearing account code from environment
      final gstAccount = environment.gstClearingAccountCode;

      // Create appropriate splits depending on whether this is income or expense
      if (isGstOnIncome) {
        // For income: GST collected goes to credit side of GST account (liability)
        return [
          SplitTransaction(accountCode: accountCode, amount: netAmount),
          SplitTransaction(accountCode: gstAccount, amount: gstAmount)
        ];
      } else {
        // For expenses: GST paid goes to debit side of GST account (asset)
        return [
          SplitTransaction(accountCode: accountCode, amount: netAmount),
          SplitTransaction(accountCode: gstAccount, amount: gstAmount)
        ];
      }
    } else {
      // Not GST inclusive, return a single transaction
      return [SplitTransaction(accountCode: accountCode, amount: amount)];
    }
  }

  /// Adds a new general journal entry
  ///
  /// Returns true if successful, false otherwise
  bool addEntry(GeneralJournal entry) {
    if (isFirstTransaction(entry)) {
      createOpeningBalance(entry);
    }

    // Check if this entry already exists in the journal
    // Only add the entry if the number of identical entries in the bank statement
    // is greater than the number of identical entries in the general journal by at least 1
    int identicalEntriesInJournal = 0;
    for (final existingEntry in entries) {
      if (existingEntry == entry) {
        identicalEntriesInJournal++;
      }
    }

    // Get the count of identical entries in the bank statement
    int identicalEntriesInBankStatement =
        services.bankStatement.countIdenticalEntries(entry);

    // Only add the entry if there are more occurrences in the bank statement than in the journal
    if (identicalEntriesInBankStatement > identicalEntriesInJournal) {
      entries.add(entry);
    } else {
      return false;
    }

    return saveEntries();
  }

  /// Creates a general journal entry from a bank import row, handling GST splitting if needed
  ///
  /// @param row The raw transaction data from a bank statement
  /// @return A new GeneralJournal entry with appropriate split transactions
  GeneralJournal createEntryFromRawFileRow(RawFileRow row) {
    // Determine if the transaction is a debit or credit to the bank account
    final isDebit = row.debit.isNotEmpty;
    final amount = isDebit
        ? double.tryParse(row.debit.replaceAll(',', '')) ?? 0.0
        : double.tryParse(row.credit.replaceAll(',', '')) ?? 0.0;

    // Get the account to determine if it's GST inclusive
    final account = services.chartOfAccounts.getAccount(row.accountCode);

    // Determine if this is income or expense for GST handling
    bool isGstOnIncome = false;
    if (account != null && account.gst) {
      isGstOnIncome = account.gstType == GstType.gstOnIncome;
    }

    // Create appropriate split transactions based on transaction type
    List<SplitTransaction> debits;
    List<SplitTransaction> credits;

    if (isDebit) {
      // Bank account is being debited, so account code is credited
      // For example: Expense transaction - debit expense account, credit bank account
      debits = _createSplitTransactionsWithGst(
          row.accountCode, amount, isGstOnIncome);
      credits = [
        SplitTransaction(accountCode: row.bankAccountCode, amount: amount)
      ];
    } else {
      // Bank account is being credited, so account code is debited
      // For example: Income transaction - debit bank account, credit income account
      debits = [
        SplitTransaction(accountCode: row.bankAccountCode, amount: amount)
      ];
      credits = _createSplitTransactionsWithGst(
          row.accountCode, amount, isGstOnIncome);
    }

    return GeneralJournal(
      date: row.date,
      description: row.description,
      debits: debits,
      credits: credits,
      bankBalance: row.balance,
      notes: row.reason,
    );
  }

  /// Counts the number of entries that are identical to the provided entry
  ///
  /// This method uses the equality operator defined in the GeneralJournal class
  /// to find entries that match the same amount, date, description, and bank account.
  /// It's useful for detecting duplicate transactions during import or reconciliation.
  ///
  /// @param entry The journal entry to compare against existing entries
  /// @return The count of identical entries found in the journal
  int countIdenticalEntries(GeneralJournal entry) {
    final matches =
        entries.where((existingEntry) => existingEntry == entry).toList();
    return matches.length;
  }

  /// Gets all general journal entries
  List<GeneralJournal> getAllEntries() {
    return List.unmodifiable(entries);
  }

  /// Gets entries filtered by account code (either in debits or credits)
  List<GeneralJournal> getEntriesByAccount(String accountCode) {
    return entries
        .where((entry) =>
            entry.debits.any((debit) => debit.accountCode == accountCode) ||
            entry.credits.any((credit) => credit.accountCode == accountCode))
        .toList();
  }

  /// Gets entries within a date range
  List<GeneralJournal> getEntriesByDateRange(DateTime start, DateTime end) {
    return entries
        .where((entry) =>
            entry.date.isAfter(start.subtract(const Duration(days: 1))) &&
            entry.date.isBefore(end.add(const Duration(days: 1))))
        .toList();
  }

  /// Calculates the balance for a specific account as of a given date
  ///
  /// This function computes the running balance for an account by summing all
  /// relevant transactions up to the specified date. It considers whether the
  /// account appears as a debit or credit in each transaction and applies the
  /// appropriate accounting logic based on the transaction type.
  ///
  /// @param accountCode The chart of accounts code to calculate the balance for
  /// @param asOfDate The date up to which transactions should be included (defaults to current date)
  /// @return The calculated account balance as a double
  double calculateAccountBalance(String accountCode, {DateTime? asOfDate}) {
    final effectiveDate = asOfDate ?? DateTime.now();
    double balance = 0.0;

    // Get the account type to determine if it increases with debit or credit
    final account = services.chartOfAccounts.getAccount(accountCode);
    if (account == null) return 0.0;

    // Filter entries by date and the specified account code
    final relevantEntries = entries
        .where((entry) =>
            (entry.date.isBefore(effectiveDate) ||
                entry.date.isAtSameMomentAs(effectiveDate)) &&
            (entry.debits.any((debit) => debit.accountCode == accountCode) ||
                entry.credits
                    .any((credit) => credit.accountCode == accountCode)))
        .toList();

    for (final entry in relevantEntries) {
      // Determine if this account type increases with debit or credit
      final increasesWithDebit = [
        AccountType.currentAsset,
        AccountType.bank,
        AccountType.inventory,
        AccountType.fixedAsset,
        AccountType.expense,
        AccountType.cogs,
      ].contains(account.type);

      // Calculate the total amount debited to this account in this entry
      double debitAmount = 0.0;
      for (final debit in entry.debits) {
        if (debit.accountCode == accountCode) {
          debitAmount += debit.amount;
        }
      }

      // Calculate the total amount credited to this account in this entry
      double creditAmount = 0.0;
      for (final credit in entry.credits) {
        if (credit.accountCode == accountCode) {
          creditAmount += credit.amount;
        }
      }

      // Apply the debits and credits according to account type
      if (increasesWithDebit) {
        balance += debitAmount - creditAmount;
      } else {
        balance += creditAmount - debitAmount;
      }
    }

    return balance;
  }
}

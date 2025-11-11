import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/bank_import_models.dart';
import 'package:ai_accounting/models/split_transaction.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:json_annotation/json_annotation.dart';

part 'general_journal.g.dart';

/// Represents a general journal entry in the accounting system
///
/// A general journal entry records financial transactions with debits and credits
/// to specific accounts, maintaining the accounting equation (Assets = Liabilities + Equity)
@JsonSerializable()
class GeneralJournal {
  /// When true, skips expensive chart-of-accounts validation (used during bulk loads).
  static bool disableAccountValidation = false;

  /// The date when the transaction occurred
  final DateTime date;

  /// Description of the transaction
  final String description;

  /// List of debit transactions
  final List<SplitTransaction> debits;

  /// List of credit transactions
  final List<SplitTransaction> credits;

  /// The running total of the bank balance which should be checked against the
  /// actual running total as calculated to ensure the account reconciles, also good
  /// for matching transactions
  final double bankBalance;

  /// Optional notes or reasoning for the transaction
  final String notes;

  /// Gets the total amount of the transaction
  double get amount {
    final debitTotal = double.parse(
        debits.fold(0.0, (sum, item) => sum + item.amount).toStringAsFixed(2));
    final creditTotal = double.parse(
        credits.fold(0.0, (sum, item) => sum + item.amount).toStringAsFixed(2));
    assert(debitTotal == creditTotal, 'Debits and credits must balance');
    return debitTotal;
  }

  /// Gets the bank account code involved in this transaction
  ///
  /// Determines whether the debit or credit side of the transaction
  /// involves a bank account and returns that account code.
  String get bankCode {
    final bankAccounts =
        services.chartOfAccounts.getAccountsByType(AccountType.bank);

    // Check debit transactions for bank accounts
    for (var debit in debits) {
      if (bankAccounts.any((account) => account.code == debit.accountCode)) {
        return debit.accountCode;
      }
    }

    // Check credit transactions for bank accounts
    for (var credit in credits) {
      if (bankAccounts.any((account) => account.code == credit.accountCode)) {
        return credit.accountCode;
      }
    }

    throw Exception('No bank account found in transaction');
  }

  /// Gets the bank account object involved in this transaction
  ///
  /// Retrieves the full Account object for the bank account
  /// involved in this transaction. Throws an exception if the
  /// bank account cannot be found.
  Account get bankAccount {
    final code = bankCode;
    var bankAccount = services.chartOfAccounts.getAccount(code);
    if (bankAccount == null) {
      throw Exception(
          'Bank account not found with code: $code. This should never happen.');
    }
    return bankAccount;
  }

  /// Creates a new GeneralJournal entry with the specified properties
  ///
  /// The total of debits must equal the total of credits.
  /// All accounts must exist in the chart of accounts.
  ///
  /// @param date The date when the transaction occurred
  /// @param description A description of the transaction
  /// @param debits List of debit transactions
  /// @param credits List of credit transactions
  /// @param bankBalance The running balance of the bank account
  /// @param notes Optional notes or reasoning for the transaction
  GeneralJournal({
    required this.date,
    required this.description,
    required this.debits,
    required this.credits,
    required this.bankBalance,
    this.notes = '',
  }) {
    // Validate that debits and credits balance
    final debitTotal = double.parse(
        debits.fold(0.0, (sum, item) => sum + item.amount).toStringAsFixed(2));
    final creditTotal = double.parse(
        credits.fold(0.0, (sum, item) => sum + item.amount).toStringAsFixed(2));
    if (debitTotal != creditTotal) {
      throw Exception(
          'Debits (\$${debitTotal.toStringAsFixed(2)}) and credits (\$${creditTotal.toStringAsFixed(2)}) must balance');
    }

    if (!disableAccountValidation) {
      // Validate that all accounts exist in the chart of accounts
      for (var debit in debits) {
        final account = services.chartOfAccounts.getAccount(debit.accountCode);
        if (account == null) {
          throw Exception(
              'Debit account with code "${debit.accountCode}" does not exist in the chart of accounts.');
        }
      }

      for (var credit in credits) {
        final account = services.chartOfAccounts.getAccount(credit.accountCode);
        if (account == null) {
          throw Exception(
              'Credit account with code "${credit.accountCode}" does not exist in the chart of accounts.');
        }
      }
    }
  }

  /// Creates a GeneralJournal entry from a RawFileRow
  ///
  /// Converts a raw bank transaction row into a proper accounting journal entry
  /// by determining the correct debit and credit accounts and formatting the description.
  ///
  /// @param row The raw transaction data from a bank statement
  /// @return A new GeneralJournal entry
  factory GeneralJournal.fromRawFileRow(RawFileRow row) {
    return services.generalJournal.createEntryFromRawFileRow(row);
  }

  /// Converts this GeneralJournal entry to a CSV row string
  ///
  /// Returns a comma-separated string with the following format:
  /// Date,Description,Debit Account,Debit Amount,Credit Account,Credit Amount,Notes
  ///
  /// The method properly escapes fields containing commas or quotes
  /// to ensure valid CSV formatting.
  ///
  /// @return A CSV-formatted string representing this journal entry
  String toCSV() {
    // Format the date as YYYY-MM-DD
    final formattedDate = date.toIso8601String().split('T')[0];

    // Escape description if it contains commas or quotes
    final escapedDescription =
        description.contains(',') || description.contains('"')
            ? '"${description.replaceAll('"', '""')}"'
            : description;

    // Escape notes if it contains commas or quotes
    final escapedNotes = notes.contains(',') || notes.contains('"')
        ? '"${notes.replaceAll('"', '""')}"'
        : notes;

    // Format debit and credit transactions
    final debitLines =
        debits.map((d) => '${d.accountCode}:${d.amount}').join(';');
    final creditLines =
        credits.map((c) => '${c.accountCode}:${c.amount}').join(';');

    return '$formattedDate,$escapedDescription,$debitLines,$creditLines,$escapedNotes';
  }

  /// Creates a GeneralJournal entry from JSON
  ///
  /// Factory constructor that deserializes a JSON map into a GeneralJournal object.
  /// Uses the generated code from json_serializable.
  ///
  /// @param json The JSON map to deserialize
  /// @return A new GeneralJournal instance
  factory GeneralJournal.fromJson(Map<String, dynamic> json) =>
      _$GeneralJournalFromJson(json);

  /// Converts this GeneralJournal entry to JSON
  ///
  /// Serializes this object into a JSON map that can be stored or transmitted.
  /// Uses the generated code from json_serializable.
  ///
  /// @return A JSON map representing this journal entry
  Map<String, dynamic> toJson() => _$GeneralJournalToJson(this);

  @override
  int get hashCode {
    // Create a hash based on the unique properties of the journal entry
    // Including account codes to match the updated equality implementation
    var debitCodesHash =
        Object.hashAll(debits.map((d) => Object.hash(d.accountCode, d.amount)));
    var creditCodesHash = Object.hashAll(
        credits.map((c) => Object.hash(c.accountCode, c.amount)));

    return Object.hash(
      date.day,
      date.month,
      date.year,
      description,
      amount,
      bankCode,
      debitCodesHash,
      creditCodesHash,
    );
  }

  /// 🛡️ DUPLICATE DETECTION: Checks if this transaction represents the same bank transaction
  ///
  /// This method determines if two transactions are duplicates based on ONLY the core
  /// bank transaction attributes, ignoring account codes (which change during categorization).
  ///
  /// **MATCHING CRITERIA:**
  /// - Bank account code (0-99 range, e.g., 001, 002, 003, 050)
  /// - Transaction date (same day)
  /// - Transaction description (exact bank line string)
  /// - Transaction amount (exact amount)
  ///
  /// **IGNORES:** Account codes in debits/credits (these change during categorization)
  ///
  /// @param other The journal entry to compare against
  /// @return True if this represents the same bank transaction, false otherwise
  bool isSameBankTransaction(GeneralJournal other) {
    return amount == other.amount &&
        date.year == other.date.year &&
        date.month == other.date.month &&
        date.day == other.date.day &&
        description == other.description &&
        bankCode == other.bankCode;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is! GeneralJournal) return false;

    // Consider an entry to be equal if it matches the amount, the date,
    // the description, the bank account, and the account codes in debits/credits
    if (amount != other.amount ||
        date.year != other.date.year ||
        date.month != other.date.month ||
        date.day != other.date.day ||
        description != other.description ||
        bankCode != other.bankCode) {
      return false;
    }

    // Compare debit and credit account codes to distinguish duplicate transactions
    if (debits.length != other.debits.length ||
        credits.length != other.credits.length) {
      return false;
    }

    // Check if all debit account codes match
    for (int i = 0; i < debits.length; i++) {
      if (debits[i].accountCode != other.debits[i].accountCode ||
          debits[i].amount != other.debits[i].amount) {
        return false;
      }
    }

    // Check if all credit account codes match
    for (int i = 0; i < credits.length; i++) {
      if (credits[i].accountCode != other.credits[i].accountCode ||
          credits[i].amount != other.credits[i].amount) {
        return false;
      }
    }

    return true;
  }
}

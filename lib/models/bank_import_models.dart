/// Represents a bank statement import file containing transaction data
///
/// This class holds the raw transaction data imported from a bank statement file
/// along with the associated bank account code from the chart of accounts.
/// It serves as a container for the parsed bank statement data before it is
/// processed and converted into general journal entries.
class BankImportFile {
  /// The list of raw transaction rows parsed from the bank statement file
  final rawFileRows = <RawFileRow>[];

  /// The chart of accounts code for the bank account this import relates to
  final String bankAccountCode;

  /// Creates a new BankImportFile instance
  ///
  /// Initializes a BankImportFile with the provided raw file rows and bank account code.
  /// The raw file rows represent the parsed data from a bank statement CSV file,
  /// and the bank account code identifies which account in the chart of accounts
  /// this import file corresponds to.
  ///
  /// @param rows The list of raw file rows parsed from the bank statement
  /// @param accountCode The chart of accounts code for this bank account
  BankImportFile({
    required List<RawFileRow> rows,
    required this.bankAccountCode,
  }) {
    rawFileRows.addAll(rows);
  }
}

/// Represents a raw transaction row from a bank statement file
///
/// This class holds the individual transaction data parsed from a bank statement,
/// including date, description, amounts, and balance. It also provides functionality
/// to retrieve AI-generated account codes and clean transaction descriptions.
class RawFileRow {
  /// The date of the transaction
  final DateTime date;

  /// Description of the transaction
  final String description;

  /// Debit amount (if applicable)
  final String debit;

  /// Credit amount (if applicable)
  final String credit;

  /// Running balance after the transaction
  final double balance;

  /// The bank account code the transaction is associated with
  final String bankAccountCode;

  /// The AI-generated account code from the chart of accounts
  String accountCode;

  /// The AI-generated reasoning for the account code assignment
  String reason;

  /// Returns the transaction as a tab-separated line for agent communication
  String get asStatementLine =>
      "${date.toIso8601String().substring(0, 10)}\t$description\t$debit\t$credit\t$balance";

  /// Returns a cleaned version of the transaction description
  ///
  /// This getter processes the raw transaction description to remove common
  /// noise elements like dates, times, reference numbers, and standardizes
  /// the format to make it more consistent for AI analysis and human readability.
  ///
  /// @return A cleaned string representation of the transaction description
  String get cleanedDescription {
    String cleaned = description;

    // Remove dates in formats like "25Dec", "19 Dec", "27Nov"
    cleaned = cleaned.replaceAll(
        RegExp(r'\d{1,2}(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)'),
        '');

    // Remove times in format like "13:49", "14:41"
    cleaned = cleaned.replaceAll(RegExp(r'\d{2}:\d{2}'), '');

    // Remove currency amounts and other numbers
    cleaned = cleaned.replaceAll(RegExp(r'\d+\.\d+'), ''); // Decimal numbers
    cleaned = cleaned.replaceAll(RegExp(r'\b\d+\b'), ''); // Whole numbers

    // Remove common transaction prefixes
    cleaned = cleaned.replaceAll(RegExp(r'Visa Purchase\s+O\/Seas\s+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'Visa Purchase\s+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'Eftpos Debit\s+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'Cash Deposit\s+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'Tfr Wdl\s+'), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'Internet (?:Deposit|Withdrawal)\s+'), 'Internet Transfer ');

    // Remove payment processor prefixes (keeping ebay and internet withdrawal)
    cleaned = cleaned.replaceAll(RegExp(r'Paypal\s*[*]\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'Ebay\s*O[*](?:\s*-*)+'),
        'Ebay '); // Preserve 'Ebay' but clean up the O* and numbers
    cleaned = cleaned.replaceAll(RegExp(r'Osko\s+(?:Payment|Deposit)\s+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'Zeller\s+Rebelli\d+'), 'Zeller');

    // Remove foreign currency indicators
    cleaned = cleaned.replaceAll(RegExp(r'Usd\s*\d+\.?\d*'), '');

    // Remove reference numbers and IDs
    cleaned = cleaned.replaceAll(RegExp(r'\b[A-Z0-9]+(?:-[A-Z0-9]+)+\b'),
        ''); // Merchant IDs, Reference numbers
    cleaned = cleaned.replaceAll(
        RegExp(r'\b\d+[A-Za-z]+\d+\b'), ''); // Mixed alphanumeric codes
    cleaned = cleaned.replaceAll(RegExp(r'(?:Cn|Ref)\d+'),
        ''); // Reference numbers starting with Cn or Ref

    // Remove store/location identifiers
    cleaned = cleaned.replaceAll(
        RegExp(r'(?<=\s)\d{4}(?=\s|$)'), ''); // 4-digit store numbers
    cleaned = cleaned.replaceAll(RegExp(r'Lot \d+(?:Cnr)?'), ''); // Lot numbers

    // Remove company suffixes
    cleaned = cleaned.replaceAll(RegExp(r'\s+Pty\s+Ltd\b'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+Pty\s+L\b'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+Group\s+Ltd\b'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+Limited\b'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+Inc\b'), '');

    // Replace punctuation with whitespace
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s]'), ' ');

    // Remove multiple spaces and trim
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Remove common location suffixes
    cleaned = cleaned.replaceAll(RegExp(r'\s+Sydney\s+Au$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+Auckland$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+Sydney\s+So$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+Cc\s+Google$'), '');

    // Remove escaped characters and special characters
    cleaned = cleaned.replaceAll(r'\,', ' ');
    cleaned = cleaned.replaceAll(RegExp(r'[*\\]'), ' ');

    // Final cleanup of any multiple spaces created
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  /// Creates a new RawFileFormat instance
  RawFileRow({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.bankAccountCode,
    this.accountCode = '',
    this.reason = '',
  });
}

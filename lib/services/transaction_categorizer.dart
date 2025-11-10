/// Categorization result for income transactions.
class IncomeCategorizationResult {
  /// Creates a new categorization decision.
  const IncomeCategorizationResult({
    required this.accountCode,
    required this.justification,
  });

  /// Account code assigned to the transaction.
  final String accountCode;

  /// Justification explaining why the account was selected.
  final String justification;
}

/// Determines the account for an income transaction based on supplier details.
IncomeCategorizationResult categorizeIncomeTransaction({
  required String supplierName,
  required String suppliesDescription,
}) {
  final supplies = suppliesDescription.toLowerCase();

  const customerKeywords = ['customer', 'payment'];
  const processingKeywords = ['processing', 'processor'];

  final matchesCustomerKeyword =
      customerKeywords.any((keyword) => supplies.contains(keyword));
  if (matchesCustomerKeyword) {
    return const IncomeCategorizationResult(
      accountCode: '100',
      justification: 'Categorised as sales revenue: customer payment for products or services',
    );
  }

  final matchesProcessingKeyword =
      processingKeywords.any((keyword) => supplies.contains(keyword));
  if (matchesProcessingKeyword) {
    return const IncomeCategorizationResult(
      accountCode: '150',
      justification: 'Categorised as other income: Processing income',
    );
  }

  return IncomeCategorizationResult(
    accountCode: '100',
    justification: 'Categorised as sales revenue: Revenue from $supplierName',
  );
}


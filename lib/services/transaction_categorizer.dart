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

/// Categorization result for expense transactions.
class ExpenseCategorizationResult {
  /// Creates a new categorization decision.
  const ExpenseCategorizationResult({
    required this.accountCode,
    required this.justification,
  });

  /// Account code assigned to the transaction.
  final String accountCode;

  /// Justification explaining why the account was selected.
  final String justification;
}

/// Internal rule used for expense classification.
class _ExpenseRule {
  const _ExpenseRule({
    required this.accountCode,
    required this.justification,
    required this.keywords,
  });

  final String accountCode;
  final String justification;
  final List<String> keywords;

  bool matches(String supplierLower, String suppliesLower) {
    return keywords.any(
      (keyword) =>
          supplierLower.contains(keyword) || suppliesLower.contains(keyword),
    );
  }
}

const _expenseFallbackAccountCode = '316'; // Office Supplies

const List<_ExpenseRule> _expenseRules = [
  _ExpenseRule(
    accountCode: '400', // Software Development Tools
    justification: 'Software and technology expense',
    keywords: [
      'software',
      'cloud',
      'subscription',
      'saas',
      'github',
      'license',
      'tool'
    ],
  ),
  _ExpenseRule(
    accountCode: '305', // Marketing & Advertising
    justification: 'Marketing or advertising spend',
    keywords: [
      'marketing',
      'advertis',
      'sponsor',
      'campaign',
      'brand',
      'rotary',
      'click business'
    ],
  ),
  _ExpenseRule(
    accountCode: '309', // Vehicle Expenses
    justification: 'Vehicle or transport cost',
    keywords: [
      'fuel',
      'vehicle',
      'transport',
      'freight',
      'delivery',
      'taxi',
      'rideshare',
      'uber',
      'logistics'
    ],
  ),
  _ExpenseRule(
    accountCode: '301', // Utilities - Distillery
    justification: 'Utilities or energy expense',
    keywords: ['utility', 'electricity', 'power', 'water', 'energy', 'gas'],
  ),
  _ExpenseRule(
    accountCode: '308', // Bank Fees
    justification: 'Bank or merchant processing fee',
    keywords: [
      'bank fee',
      'transaction fee',
      'merchant',
      'currency',
      'exchange',
      'paypal',
      'stripe',
      'pin payment',
      'processing fee'
    ],
  ),
  _ExpenseRule(
    accountCode: '300', // Rent - Distillery
    justification: 'Rent or property expense',
    keywords: [
      'rent',
      'lease',
      'property',
      'office space',
      'premises',
      'unit 27'
    ],
  ),
  _ExpenseRule(
    accountCode: '206', // Other Ingredients
    justification: 'Ingredients or consumables purchase',
    keywords: [
      'ingredient',
      'molasses',
      'coles',
      'woolworths',
      'grocery',
      'yeast',
      'supplies',
      'chemron'
    ],
  ),
  _ExpenseRule(
    accountCode: '203', // Bottles & Packaging
    justification: 'Bottling or packaging materials',
    keywords: ['bottle', 'label', 'packaging', 'uniquepak', 'label plus'],
  ),
  _ExpenseRule(
    accountCode: '317', // Training & Education
    justification: 'Training or professional development',
    keywords: ['training', 'education', 'course', 'conference', 'webinar'],
  ),
  _ExpenseRule(
    accountCode: '318', // Trade Shows & Memberships
    justification: 'Trade show or membership fee',
    keywords: ['trade show', 'membership', 'association', 'club', 'network'],
  ),
  _ExpenseRule(
    accountCode: '319', // Distillery Equipment
    justification: 'Distillery equipment or maintenance',
    keywords: [
      'distillery equipment',
      'equipment maintenance',
      'adrian smith',
      'machinery'
    ],
  ),
];

/// Exported set of all account codes referenced by the categorizer.
Set<String> categorizerAccountCodes() {
  final incomeCodes = {'100', '150'};
  final expenseCodes = _expenseRules.map((rule) => rule.accountCode).toSet()
    ..add(_expenseFallbackAccountCode);
  return {...incomeCodes, ...expenseCodes};
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
      justification:
          'Categorised as sales revenue: customer payment for products or services',
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

/// Determines the account for an expense transaction based on supplier details.
ExpenseCategorizationResult categorizeExpenseTransaction({
  required String supplierName,
  required String suppliesDescription,
}) {
  final supplierLower = supplierName.toLowerCase();
  final suppliesLower = suppliesDescription.toLowerCase();

  for (final rule in _expenseRules) {
    if (rule.matches(supplierLower, suppliesLower)) {
      return ExpenseCategorizationResult(
        accountCode: rule.accountCode,
        justification: rule.justification,
      );
    }
  }

  return ExpenseCategorizationResult(
    accountCode: _expenseFallbackAccountCode,
    justification:
        'General office expense for $supplierName – defaulting to Office Supplies (316)',
  );
}

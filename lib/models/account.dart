import 'package:json_annotation/json_annotation.dart';

part 'account.g.dart';

// This file provides the unique gstType and type fields from the chartOfAccounts data

/// Represents the unique GST Type values found in the chart of accounts.
enum GstType {
  /// GST on Income - Applies to revenue accounts where GST is collected.
  gstOnIncome('GST on Income'),

  /// GST on Expenses - Applies to expense accounts where GST is paid.
  gstOnExpenses('GST on Expenses'),

  /// GST Free Expenses - Applies to expense accounts exempt from GST.
  gstFreeExpenses('GST Free Expenses'),

  /// BAS Excluded - Applies to accounts that are excluded from Business Activity Statement.
  basExcluded('BAS Excluded'),

  /// GST on Capital - Applies to capital expenditure accounts where GST is paid.
  gstOnCapital('GST on Capital');

  /// The string representation of the GST type.
  final String value;

  /// Creates a new GST type with the given string value.
  const GstType(this.value);

  /// Returns the string representation of this GST type.
  @override
  String toString() => value;

  /// List of all available GST types as strings.
  static List<String> get all =>
      GstType.values.map((type) => type.value).toList();
}

/// Represents the unique account types found in the chart of accounts.
enum AccountType {
  /// Bank - Applies to bank accounts.
  bank('Bank'),

  /// Revenue - Applies to income from main business activities.
  revenue('Revenue'),

  /// Other Income - Applies to income from non-core business activities.
  otherIncome('Other Income'),

  /// COGS - Cost of Goods Sold, applies to direct costs of producing goods/services.
  cogs('COGS'),

  /// Expense - Applies to general business expenses.
  expense('Expense'),

  /// Depreciation - Applies to accounts tracking asset value reduction over time.
  depreciation('Depreciation'),

  /// Current Asset - Applies to assets expected to be converted to cash within a year.
  currentAsset('Current Asset'),

  /// Inventory - Applies to accounts tracking goods held for sale.
  inventory('Inventory'),

  /// Fixed Asset - Applies to long-term tangible assets.
  fixedAsset('Fixed Asset'),

  /// Current Liability - Applies to debts/obligations due within a year.
  currentLiability('Current Liability'),

  /// Equity - Applies to owner's interest in the business.
  equity('Equity');

  /// The string representation of the account type.
  final String value;

  /// Creates a new account type with the given string value.
  const AccountType(this.value);

  /// Returns the string representation of this account type.
  @override
  String toString() => value;

  /// List of all available account types as strings.
  static List<String> get all =>
      AccountType.values.map((type) => type.value).toList();
}

/// Represents an accounting account in the chart of accounts
@JsonSerializable()
class Account {
  /// MongoDB ObjectId
  @JsonKey(name: '_id')
  final Map<String, String>? id;

  /// Unique account code identifier (e.g., "090", "200")
  final String code;

  /// Human readable name of the account
  final String name;

  /// The type of account (Bank, Revenue, Expense, etc.)
  @JsonKey(
    fromJson: _accountTypeFromJson,
    toJson: _accountTypeToJson,
  )
  final AccountType type;

  /// Whether GST applies to this account
  final bool gst;

  /// The specific GST treatment for this account
  @JsonKey(
    fromJson: _gstTypeFromJson,
    toJson: _gstTypeToJson,
  )
  final GstType gstType;

  /// Creates a new Account with the specified properties
  const Account({
    this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.gst,
    required this.gstType,
  });

  /// Creates an Account from JSON
  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);

  /// Converts this Account to JSON
  Map<String, dynamic> toJson() => _$AccountToJson(this);

  /// Convert string to AccountType enum
  static AccountType _accountTypeFromJson(String value) {
    return AccountType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => AccountType.expense, // Default to expense if not found
    );
  }

  /// Convert AccountType enum to string
  static String _accountTypeToJson(AccountType type) => type.value;

  /// Convert string to GstType enum
  static GstType _gstTypeFromJson(String value) {
    return GstType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => GstType.basExcluded, // Default to BAS Excluded if not found
    );
  }

  /// Convert GstType enum to string
  static String _gstTypeToJson(GstType type) => type.value;
}

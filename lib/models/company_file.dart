import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/supplier.dart';
import 'package:json_annotation/json_annotation.dart';

part 'company_file.g.dart';

/// 🏢 **COMPANY FILE MODEL**: Centralized container for all company-specific data
///
/// This model consolidates the following company data:
/// - Chart of accounts (accounts.json)
/// - General journal entries (general_journal.json)
/// - Company profile information (company_profile.txt)
/// - Accounting rules (accounting_rules.txt)
/// - Supplier list (supplier_list.json)
///
/// **DESIGN PRINCIPLES:**
/// - Immutable data container (no direct modification)
/// - Strong typing with no dynamic maps
/// - Comprehensive validation
/// - Atomic operations for data integrity
@JsonSerializable()
class CompanyFile {
  /// Unique identifier for this company file
  final String id;

  /// Company name and basic information
  final CompanyProfile profile;

  /// Chart of accounts with all account definitions
  final List<Account> accounts;

  /// General journal with all transaction entries
  final List<GeneralJournal> generalJournal;

  /// Accounting rules and categorization logic
  final List<AccountingRule> accountingRules;

  /// Supplier list with categorization information
  final List<SupplierModel> suppliers;

  /// Metadata about the company file
  final CompanyFileMetadata metadata;

  /// Creates a new CompanyFile with all required data
  const CompanyFile({
    required this.id,
    required this.profile,
    required this.accounts,
    required this.generalJournal,
    required this.accountingRules,
    required this.suppliers,
    required this.metadata,
  });

  /// Creates a CompanyFile from JSON
  factory CompanyFile.fromJson(Map<String, dynamic> json) =>
      _$CompanyFileFromJson(json);

  /// Converts this CompanyFile to JSON
  Map<String, dynamic> toJson() => _$CompanyFileToJson(this);

  /// Creates a copy with updated fields
  CompanyFile copyWith({
    String? id,
    CompanyProfile? profile,
    List<Account>? accounts,
    List<GeneralJournal>? generalJournal,
    List<AccountingRule>? accountingRules,
    List<SupplierModel>? suppliers,
    CompanyFileMetadata? metadata,
  }) {
    return CompanyFile(
      id: id ?? this.id,
      profile: profile ?? this.profile,
      accounts: accounts ?? this.accounts,
      generalJournal: generalJournal ?? this.generalJournal,
      accountingRules: accountingRules ?? this.accountingRules,
      suppliers: suppliers ?? this.suppliers,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Validates the company file data integrity
  ///
  /// Returns a list of validation errors, empty list if valid
  List<String> validate() {
    final errors = <String>[];

    // Validate profile
    if (profile.name.isEmpty) {
      errors.add('Company name cannot be empty');
    }

    // Validate accounts
    if (accounts.isEmpty) {
      errors.add('Chart of accounts cannot be empty');
    }

    // Check for duplicate account codes
    final accountCodes = accounts.map((a) => a.code).toSet();
    if (accountCodes.length != accounts.length) {
      errors.add('Duplicate account codes found');
    }

    // Validate general journal entries
    for (int i = 0; i < generalJournal.length; i++) {
      final entry = generalJournal[i];
      try {
        // This will throw if debits/credits don't balance
        final _ = entry.amount;
      } catch (e) {
        errors.add('General journal entry $i: ${e.toString()}');
      }
    }

    // Validate accounting rules
    for (int i = 0; i < accountingRules.length; i++) {
      final rule = accountingRules[i];
      if (rule.condition.isEmpty) {
        errors.add('Accounting rule $i: condition cannot be empty');
      }
      if (rule.action.isEmpty) {
        errors.add('Accounting rule $i: action cannot be empty');
      }
      if (rule.accountCode.isEmpty) {
        errors.add('Accounting rule $i: account code cannot be empty');
      }
    }

    // Validate suppliers
    for (int i = 0; i < suppliers.length; i++) {
      final supplier = suppliers[i];
      if (supplier.name.isEmpty) {
        errors.add('Supplier $i: name cannot be empty');
      }
      if (supplier.supplies.isEmpty) {
        errors.add('Supplier $i: supplies description cannot be empty');
      }
    }

    return errors;
  }

  /// Gets the total number of transactions in the general journal
  int get transactionCount => generalJournal.length;

  /// Gets the total number of accounts in the chart of accounts
  int get accountCount => accounts.length;

  /// Gets the total number of suppliers
  int get supplierCount => suppliers.length;

  /// Gets the total number of accounting rules
  int get ruleCount => accountingRules.length;

  /// Gets accounts filtered by type
  List<Account> getAccountsByType(AccountType type) {
    return accounts.where((account) => account.type == type).toList();
  }

  /// Gets an account by its code
  Account? getAccount(String code) {
    try {
      return accounts.firstWhere((account) => account.code == code);
    } catch (e) {
      return null;
    }
  }

  /// Gets suppliers with account codes assigned
  List<SupplierModel> getSuppliersWithAccounts() {
    return suppliers.where((supplier) => supplier.hasAccountCode).toList();
  }

  /// Gets suppliers without account codes
  List<SupplierModel> getSuppliersWithoutAccounts() {
    return suppliers.where((supplier) => !supplier.hasAccountCode).toList();
  }

  @override
  String toString() =>
      'CompanyFile(id: $id, name: ${profile.name}, accounts: $accountCount, transactions: $transactionCount, suppliers: $supplierCount, rules: $ruleCount)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompanyFile &&
        other.id == id &&
        other.profile == profile &&
        other.accounts.length == accounts.length &&
        other.generalJournal.length == generalJournal.length &&
        other.accountingRules.length == accountingRules.length &&
        other.suppliers.length == suppliers.length;
  }

  @override
  int get hashCode => Object.hash(
        id,
        profile,
        Object.hashAll(accounts.map((a) => a.code)),
        Object.hashAll(generalJournal.map((g) => g.hashCode)),
        Object.hashAll(accountingRules.map((r) => r.hashCode)),
        Object.hashAll(suppliers.map((s) => s.hashCode)),
      );
}

/// 🏢 **COMPANY PROFILE**: Basic company information and details
@JsonSerializable()
class CompanyProfile {
  /// Company name
  final String name;

  /// Industry description
  final String industry;

  /// Physical address
  final String location;

  /// Founder/owner information
  final String founder;

  /// Company mission statement
  final String mission;

  /// List of products/services
  final List<String> products;

  /// Key operational purchases
  final List<String> keyPurchases;

  /// Sustainability practices
  final List<String> sustainabilityPractices;

  /// Community involvement and values
  final List<String> communityValues;

  /// Unique selling points
  final List<String> uniqueSellingPoints;

  /// Accounting considerations
  final List<String> accountingConsiderations;

  /// Creates a new CompanyProfile
  const CompanyProfile({
    required this.name,
    required this.industry,
    required this.location,
    required this.founder,
    required this.mission,
    required this.products,
    required this.keyPurchases,
    required this.sustainabilityPractices,
    required this.communityValues,
    required this.uniqueSellingPoints,
    required this.accountingConsiderations,
  });

  /// Creates a CompanyProfile from JSON
  factory CompanyProfile.fromJson(Map<String, dynamic> json) =>
      _$CompanyProfileFromJson(json);

  /// Converts this CompanyProfile to JSON
  Map<String, dynamic> toJson() => _$CompanyProfileToJson(this);

  /// Creates a copy with updated fields
  CompanyProfile copyWith({
    String? name,
    String? industry,
    String? location,
    String? founder,
    String? mission,
    List<String>? products,
    List<String>? keyPurchases,
    List<String>? sustainabilityPractices,
    List<String>? communityValues,
    List<String>? uniqueSellingPoints,
    List<String>? accountingConsiderations,
  }) {
    return CompanyProfile(
      name: name ?? this.name,
      industry: industry ?? this.industry,
      location: location ?? this.location,
      founder: founder ?? this.founder,
      mission: mission ?? this.mission,
      products: products ?? this.products,
      keyPurchases: keyPurchases ?? this.keyPurchases,
      sustainabilityPractices:
          sustainabilityPractices ?? this.sustainabilityPractices,
      communityValues: communityValues ?? this.communityValues,
      uniqueSellingPoints: uniqueSellingPoints ?? this.uniqueSellingPoints,
      accountingConsiderations:
          accountingConsiderations ?? this.accountingConsiderations,
    );
  }

  @override
  String toString() => 'CompanyProfile(name: $name, industry: $industry)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompanyProfile &&
        other.name == name &&
        other.industry == industry &&
        other.location == location &&
        other.founder == founder &&
        other.mission == mission;
  }

  @override
  int get hashCode => Object.hash(name, industry, location, founder, mission);
}

/// 📋 **ACCOUNTING RULE**: Business logic for transaction categorization
@JsonSerializable()
class AccountingRule {
  /// Unique identifier for the rule
  final String id;

  /// Rule name/description
  final String name;

  /// Condition text to match transactions
  final String condition;

  /// Action to take when condition matches
  final String action;

  /// Account code to categorize matching transactions
  final String accountCode;

  /// Account type for the rule
  final String accountType;

  /// GST handling instruction
  final String gstHandling;

  /// Priority level (1=lowest, 10=highest)
  final int priority;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last modification timestamp
  final DateTime modifiedAt;

  /// Additional notes about the rule
  final String notes;

  /// Creates a new AccountingRule
  const AccountingRule({
    required this.id,
    required this.name,
    required this.condition,
    required this.action,
    required this.accountCode,
    required this.accountType,
    required this.gstHandling,
    required this.priority,
    required this.createdAt,
    required this.modifiedAt,
    this.notes = '',
  });

  /// Creates an AccountingRule from JSON
  factory AccountingRule.fromJson(Map<String, dynamic> json) =>
      _$AccountingRuleFromJson(json);

  /// Converts this AccountingRule to JSON
  Map<String, dynamic> toJson() => _$AccountingRuleToJson(this);

  /// Creates a copy with updated fields
  AccountingRule copyWith({
    String? id,
    String? name,
    String? condition,
    String? action,
    String? accountCode,
    String? accountType,
    String? gstHandling,
    int? priority,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? notes,
  }) {
    return AccountingRule(
      id: id ?? this.id,
      name: name ?? this.name,
      condition: condition ?? this.condition,
      action: action ?? this.action,
      accountCode: accountCode ?? this.accountCode,
      accountType: accountType ?? this.accountType,
      gstHandling: gstHandling ?? this.gstHandling,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() =>
      'AccountingRule(id: $id, name: $name, priority: $priority)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountingRule &&
        other.id == id &&
        other.name == name &&
        other.condition == condition &&
        other.action == action &&
        other.accountCode == accountCode;
  }

  @override
  int get hashCode => Object.hash(id, name, condition, action, accountCode);
}

/// 📊 **COMPANY FILE METADATA**: Information about the file itself
@JsonSerializable()
class CompanyFileMetadata {
  /// File version for compatibility tracking
  final String version;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last modification timestamp
  final DateTime modifiedAt;

  /// File size in bytes
  final int fileSize;

  /// Checksum for integrity verification
  final String checksum;

  /// Backup timestamp
  final DateTime? lastBackup;

  /// Number of backup files
  final int backupCount;

  /// Creates a new CompanyFileMetadata
  const CompanyFileMetadata({
    required this.version,
    required this.createdAt,
    required this.modifiedAt,
    required this.fileSize,
    required this.checksum,
    this.lastBackup,
    this.backupCount = 0,
  });

  /// Creates CompanyFileMetadata from JSON
  factory CompanyFileMetadata.fromJson(Map<String, dynamic> json) =>
      _$CompanyFileMetadataFromJson(json);

  /// Converts this CompanyFileMetadata to JSON
  Map<String, dynamic> toJson() => _$CompanyFileMetadataToJson(this);

  /// Creates a copy with updated fields
  CompanyFileMetadata copyWith({
    String? version,
    DateTime? createdAt,
    DateTime? modifiedAt,
    int? fileSize,
    String? checksum,
    DateTime? lastBackup,
    int? backupCount,
  }) {
    return CompanyFileMetadata(
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      fileSize: fileSize ?? this.fileSize,
      checksum: checksum ?? this.checksum,
      lastBackup: lastBackup ?? this.lastBackup,
      backupCount: backupCount ?? this.backupCount,
    );
  }

  @override
  String toString() =>
      'CompanyFileMetadata(version: $version, created: $createdAt, modified: $modifiedAt)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompanyFileMetadata &&
        other.version == version &&
        other.createdAt == createdAt &&
        other.modifiedAt == modifiedAt;
  }

  @override
  int get hashCode => Object.hash(version, createdAt, modifiedAt);
}




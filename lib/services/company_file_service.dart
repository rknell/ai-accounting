import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/company_file.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/supplier.dart';
import 'package:ai_accounting/utils/journal_sanitizer.dart';
import 'package:crypto/crypto.dart';

/// 🏢 **COMPANY FILE SERVICE**: Centralized service for managing company file operations
///
/// This service provides a unified interface for:
/// - Loading and saving company files
/// - Migrating from individual file formats
/// - Data validation and integrity checks
/// - Backup and restore operations
/// - Atomic operations for data consistency
///
/// **SECURITY PRINCIPLES:**
/// - No direct file manipulation by LLMs/AIs
/// - All operations go through this service
/// - Comprehensive validation before any save operations
/// - Automatic backup creation before modifications
class CompanyFileService {
  /// 🛡️ TEST MODE: Prevents file operations when true
  final bool _testMode;

  /// Current company file in memory
  CompanyFile? _currentCompanyFile;

  /// Flag indicating if data has been loaded
  bool _isLoaded = false;

  /// Path to the currently loaded/saved company file
  String? _currentFilePath;

  /// Default constructor
  CompanyFileService({bool testMode = false}) : _testMode = testMode;

  /// Gets the current company file
  CompanyFile? get currentCompanyFile => _currentCompanyFile;

  /// Checks if a company file is currently loaded
  bool get isLoaded => _isLoaded && _currentCompanyFile != null;

  /// Returns the currently loaded company file path, if any
  String? get currentFilePath => _currentFilePath;

  /// Default path for the unified company file
  String get defaultCompanyFilePath =>
      Platform.environment['AI_ACCOUNTING_COMPANY_FILE'] ??
      'data/company_file.json';

  /// Indicates whether a persisted company file already exists
  bool get hasPersistedCompanyFile => File(defaultCompanyFilePath).existsSync();

  /// Ensures the unified company file is available (migrating if needed)
  bool ensureCompanyFileReady({String? filePath}) {
    if (isLoaded) {
      return true;
    }

    final resolvedPath = filePath ?? defaultCompanyFilePath;
    _currentFilePath = resolvedPath;

    if (_testMode) {
      print('🛡️ TEST MODE: Skipping automatic company file loading');
      return false;
    }

    final file = File(resolvedPath);
    if (file.existsSync()) {
      return loadCompanyFile(resolvedPath);
    }

    print('📦 Unified company file not found at $resolvedPath.');
    print('🔄 Attempting migration from individual inputs/data directories...');
    final migrated = migrateFromIndividualFiles();
    if (!migrated) {
      print('❌ Migration failed – continuing to use legacy files.');
      return false;
    }

    return saveCompanyFile(resolvedPath);
  }

  /// Persists the in-memory company file using the current/default path
  bool saveCurrentCompanyFile() {
    if (_testMode) {
      print('🛡️ TEST MODE: Skipping company file save');
      return true;
    }

    final targetPath = _currentFilePath ?? defaultCompanyFilePath;
    _currentFilePath = targetPath;
    return saveCompanyFile(targetPath);
  }

  /// Updates the current company file via [updater] and persists it
  bool updateCompanyFile(CompanyFile Function(CompanyFile current) updater,
      {bool persist = true}) {
    if (_currentCompanyFile == null) {
      print('❌ No company file loaded to update');
      return false;
    }

    _currentCompanyFile = updater(_currentCompanyFile!);
    _isLoaded = true;

    if (!persist || _testMode) {
      return true;
    }

    return saveCurrentCompanyFile();
  }

  /// Loads a company file from the specified path
  ///
  /// Returns true if successful, false otherwise
  bool loadCompanyFile(String filePath) {
    if (_testMode) {
      print('🛡️ TEST MODE: Skipping file load operation');
      return true;
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        print('Company file not found: $filePath');
        return false;
      }

      final jsonString = file.readAsStringSync();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      if (jsonMap['generalJournal'] is List) {
        jsonMap['generalJournal'] = (jsonMap['generalJournal'] as List<dynamic>)
            .map((entry) => JournalSanitizer.sanitizeEntry(
                  Map<String, dynamic>.from(entry as Map<String, dynamic>),
                  log: (message) => print(message),
                ))
            .toList();
      }

      final previousValidationState = GeneralJournal.disableAccountValidation;
      GeneralJournal.disableAccountValidation = true;
      try {
        _currentCompanyFile = CompanyFile.fromJson(jsonMap);
      } finally {
        GeneralJournal.disableAccountValidation = previousValidationState;
      }

      // Validate the loaded data
      final validationErrors = _currentCompanyFile!.validate();
      if (validationErrors.isNotEmpty) {
        print('⚠️ Company file validation errors:');
        for (final error in validationErrors) {
          print('  - $error');
        }
        // Don't fail completely, but warn about issues
      }

      _currentFilePath = filePath;
      _isLoaded = true;
      print(
          '✅ Company file loaded successfully: ${_currentCompanyFile!.profile.name}');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error loading company file: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Saves the current company file to the specified path
  ///
  /// Returns true if successful, false otherwise
  bool saveCompanyFile(String filePath) {
    if (_testMode) {
      print('🛡️ TEST MODE: Skipping file save operation');
      return true;
    }

    if (_currentCompanyFile == null) {
      print('❌ No company file loaded to save');
      return false;
    }

    try {
      _currentFilePath = filePath;

      // Create backup before saving
      _createBackup(filePath);

      // Update metadata
      final updatedMetadata = _currentCompanyFile!.metadata.copyWith(
        modifiedAt: DateTime.now(),
        fileSize: 0, // Will be calculated after saving
      );

      final updatedCompanyFile = _currentCompanyFile!.copyWith(
        metadata: updatedMetadata,
      );

      // Validate before saving
      final validationErrors = updatedCompanyFile.validate();
      if (validationErrors.isNotEmpty) {
        print('❌ Cannot save company file with validation errors:');
        for (final error in validationErrors) {
          print('  - $error');
        }
        return false;
      }

      // Convert to JSON and save
      final previousValidationState = GeneralJournal.disableAccountValidation;
      GeneralJournal.disableAccountValidation = true;
      late final String jsonString;
      try {
        jsonString = jsonEncode(updatedCompanyFile.toJson());
      } finally {
        GeneralJournal.disableAccountValidation = previousValidationState;
      }
      final file = File(filePath);

      // Ensure directory exists
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonString);

      // Update file size in metadata
      final finalMetadata = updatedMetadata.copyWith(
        fileSize: file.lengthSync(),
        checksum: _calculateChecksum(jsonString),
      );

      _currentCompanyFile = updatedCompanyFile.copyWith(
        metadata: finalMetadata,
      );

      print('✅ Company file saved successfully: $filePath');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error saving company file: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Creates a new company file by migrating from individual files
  ///
  /// This method reads the existing individual files and consolidates them
  /// into a single company file structure.
  ///
  /// Returns true if successful, false otherwise
  bool migrateFromIndividualFiles({
    String? accountsPath,
    String? generalJournalPath,
    String? companyProfilePath,
    String? accountingRulesPath,
    String? supplierListPath,
  }) {
    if (_testMode) {
      print('🛡️ TEST MODE: Skipping migration operation');
      return true;
    }

    try {
      print('🔄 Starting migration from individual files...');

      // Set default paths if not provided
      accountsPath ??= 'inputs/accounts.json';
      generalJournalPath ??= 'data/general_journal.json';
      companyProfilePath ??= 'inputs/company_profile.txt';
      accountingRulesPath ??= 'inputs/accounting_rules.txt';
      supplierListPath ??= 'inputs/supplier_list.json';

      // Load accounts
      final accounts = _loadAccounts(accountsPath);
      if (accounts.isEmpty) {
        print('❌ Failed to load accounts from $accountsPath');
        return false;
      }

      // Load general journal
      final generalJournal = _loadGeneralJournal(generalJournalPath);
      print('📊 Loaded ${generalJournal.length} journal entries');

      // Load company profile
      final profile = _loadCompanyProfile(companyProfilePath);
      if (profile == null) {
        print('❌ Failed to load company profile from $companyProfilePath');
        return false;
      }

      // Load accounting rules
      final accountingRules = _loadAccountingRules(accountingRulesPath);
      print('📋 Loaded ${accountingRules.length} accounting rules');

      // Load suppliers
      final suppliers = _loadSuppliers(supplierListPath);
      print('🏪 Loaded ${suppliers.length} suppliers');

      // Create metadata
      final metadata = CompanyFileMetadata(
        version: '1.0.0',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        fileSize: 0,
        checksum: '',
      );

      // Create company file
      _currentCompanyFile = CompanyFile(
        id: _generateCompanyFileId(),
        profile: profile,
        accounts: accounts,
        generalJournal: generalJournal,
        accountingRules: accountingRules,
        suppliers: suppliers,
        metadata: metadata,
      );

      _isLoaded = true;
      print('✅ Migration completed successfully');
      print('🏢 Company: ${profile.name}');
      print('📊 Accounts: ${accounts.length}');
      print('📝 Transactions: ${generalJournal.length}');
      print('📋 Rules: ${accountingRules.length}');
      print('🏪 Suppliers: ${suppliers.length}');

      return true;
    } catch (e, stackTrace) {
      print('❌ Error during migration: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Loads accounts from the specified JSON file
  List<Account> _loadAccounts(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        print('⚠️ Accounts file not found: $filePath');
        return [];
      }

      final jsonString = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;

      return jsonList
          .map((jsonMap) => Account.fromJson(jsonMap as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error loading accounts: $e');
      return [];
    }
  }

  /// Loads general journal entries from the specified JSON file
  List<GeneralJournal> _loadGeneralJournal(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        print('⚠️ General journal file not found: $filePath');
        return [];
      }

      final jsonString = file.readAsStringSync();
      if (jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;

      return jsonList
          .map((jsonMap) =>
              GeneralJournal.fromJson(jsonMap as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error loading general journal: $e');
      return [];
    }
  }

  /// Loads company profile from the specified text file
  CompanyProfile? _loadCompanyProfile(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        print('⚠️ Company profile file not found: $filePath');
        return null;
      }

      final lines = file.readAsLinesSync();

      // Parse the company profile text format
      String name = '';
      String industry = '';
      String location = '';
      String founder = '';
      String mission = '';
      List<String> products = [];
      List<String> keyPurchases = [];
      List<String> sustainabilityPractices = [];
      List<String> communityValues = [];
      List<String> uniqueSellingPoints = [];
      List<String> accountingConsiderations = [];

      String currentSection = '';

      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        if (trimmedLine.startsWith('Company Name:')) {
          name = trimmedLine.substring('Company Name:'.length).trim();
        } else if (trimmedLine.startsWith('Industry:')) {
          industry = trimmedLine.substring('Industry:'.length).trim();
        } else if (trimmedLine.startsWith('Location:')) {
          location = trimmedLine.substring('Location:'.length).trim();
        } else if (trimmedLine.startsWith('Founder:')) {
          founder = trimmedLine.substring('Founder:'.length).trim();
        } else if (trimmedLine.startsWith('Mission:')) {
          mission = trimmedLine.substring('Mission:'.length).trim();
        } else if (trimmedLine.startsWith('Products:')) {
          currentSection = 'products';
        } else if (trimmedLine.startsWith('Key Purchases for Operations:')) {
          currentSection = 'keyPurchases';
        } else if (trimmedLine.startsWith('Sustainability Practices:')) {
          currentSection = 'sustainabilityPractices';
        } else if (trimmedLine.startsWith('Community & Values:')) {
          currentSection = 'communityValues';
        } else if (trimmedLine.startsWith('Unique Selling Points:')) {
          currentSection = 'uniqueSellingPoints';
        } else if (trimmedLine.startsWith('Accounting Considerations:')) {
          currentSection = 'accountingConsiderations';
        } else if (trimmedLine.startsWith('-') && currentSection.isNotEmpty) {
          final item = trimmedLine.substring(1).trim();
          switch (currentSection) {
            case 'products':
              products.add(item);
              break;
            case 'keyPurchases':
              keyPurchases.add(item);
              break;
            case 'sustainabilityPractices':
              sustainabilityPractices.add(item);
              break;
            case 'communityValues':
              communityValues.add(item);
              break;
            case 'uniqueSellingPoints':
              uniqueSellingPoints.add(item);
              break;
            case 'accountingConsiderations':
              accountingConsiderations.add(item);
              break;
          }
        }
      }

      return CompanyProfile(
        name: name,
        industry: industry,
        location: location,
        founder: founder,
        mission: mission,
        products: products,
        keyPurchases: keyPurchases,
        sustainabilityPractices: sustainabilityPractices,
        communityValues: communityValues,
        uniqueSellingPoints: uniqueSellingPoints,
        accountingConsiderations: accountingConsiderations,
      );
    } catch (e) {
      print('❌ Error loading company profile: $e');
      return null;
    }
  }

  /// Loads accounting rules from the specified text file
  List<AccountingRule> _loadAccountingRules(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        print('⚠️ Accounting rules file not found: $filePath');
        return [];
      }

      final lines = file.readAsLinesSync();
      final rules = <AccountingRule>[];

      String currentRuleText = '';

      for (final line in lines) {
        if (line.startsWith('=== ACCOUNTING RULE:')) {
          // Process previous rule if exists
          if (currentRuleText.isNotEmpty) {
            final rule = _parseAccountingRule(currentRuleText);
            if (rule != null) {
              rules.add(rule);
            }
          }
          currentRuleText = line;
        } else {
          currentRuleText += '\n$line';
        }
      }

      // Process last rule
      if (currentRuleText.isNotEmpty) {
        final rule = _parseAccountingRule(currentRuleText);
        if (rule != null) {
          rules.add(rule);
        }
      }

      return rules;
    } catch (e) {
      print('❌ Error loading accounting rules: $e');
      return [];
    }
  }

  /// Parses a single accounting rule from text
  AccountingRule? _parseAccountingRule(String ruleText) {
    try {
      final lines = ruleText.split('\n');

      String name = '';
      String condition = '';
      String action = '';
      String accountCode = '';
      String accountType = '';
      String gstHandling = '';
      int priority = 5;
      DateTime createdAt = DateTime.now();
      DateTime modifiedAt = DateTime.now();
      String notes = '';

      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        if (trimmedLine.startsWith('=== ACCOUNTING RULE:')) {
          name = trimmedLine.substring('=== ACCOUNTING RULE:'.length).trim();
        } else if (trimmedLine.startsWith('Created:')) {
          final dateStr = trimmedLine.substring('Created:'.length).trim();
          createdAt = DateTime.parse(dateStr);
        } else if (trimmedLine.startsWith('Priority:')) {
          final priorityStr = trimmedLine.substring('Priority:'.length).trim();
          priority = int.tryParse(priorityStr) ?? 5;
        } else if (trimmedLine.startsWith('Condition:')) {
          condition = trimmedLine.substring('Condition:'.length).trim();
        } else if (trimmedLine.startsWith('Action:')) {
          action = trimmedLine.substring('Action:'.length).trim();
        } else if (trimmedLine.startsWith('Account Code:')) {
          final codeStr = trimmedLine.substring('Account Code:'.length).trim();
          final codeMatch = RegExp(r'(\d+)\s*\(([^)]+)\)').firstMatch(codeStr);
          if (codeMatch != null) {
            accountCode = codeMatch.group(1)!;
            accountType = codeMatch.group(2)!;
          }
        } else if (trimmedLine.startsWith('Account Type:')) {
          accountType = trimmedLine.substring('Account Type:'.length).trim();
        } else if (trimmedLine.startsWith('GST Handling:')) {
          gstHandling = trimmedLine.substring('GST Handling:'.length).trim();
        } else if (trimmedLine.startsWith('Notes:')) {
          notes = trimmedLine.substring('Notes:'.length).trim();
        }
      }

      if (name.isEmpty || condition.isEmpty || action.isEmpty) {
        return null;
      }

      return AccountingRule(
        id: _generateRuleId(),
        name: name,
        condition: condition,
        action: action,
        accountCode: accountCode,
        accountType: accountType,
        gstHandling: gstHandling,
        priority: priority,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        notes: notes,
      );
    } catch (e) {
      print('❌ Error parsing accounting rule: $e');
      return null;
    }
  }

  /// Loads suppliers from the specified JSON file
  List<SupplierModel> _loadSuppliers(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        print('⚠️ Supplier list file not found: $filePath');
        return [];
      }

      final jsonString = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;

      return jsonList
          .map((jsonMap) =>
              SupplierModel.fromJson(jsonMap as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error loading suppliers: $e');
      return [];
    }
  }

  /// Creates a backup of the company file before saving
  void _createBackup(String originalPath) {
    try {
      final originalFile = File(originalPath);
      if (!originalFile.existsSync()) return;

      final backupDir = Directory('${originalFile.parent.path}/backups');
      if (!backupDir.existsSync()) {
        backupDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath =
          '${backupDir.path}/company_file_backup_$timestamp.json';

      originalFile.copySync(backupPath);
      print('💾 Backup created: $backupPath');
    } catch (e) {
      print('⚠️ Warning: Could not create backup: $e');
    }
  }

  /// Calculates a checksum for the file content
  String _calculateChecksum(String content) {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generates a unique company file ID
  String _generateCompanyFileId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'company_${timestamp}_$random';
  }

  /// Generates a unique rule ID
  String _generateRuleId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'rule_${timestamp}_$random';
  }

  /// Gets accounts filtered by type
  List<Account> getAccountsByType(AccountType type) {
    if (_currentCompanyFile == null) return [];
    return _currentCompanyFile!.getAccountsByType(type);
  }

  /// Gets an account by its code
  Account? getAccount(String code) {
    if (_currentCompanyFile == null) return null;
    return _currentCompanyFile!.getAccount(code);
  }

  /// Gets all accounts
  List<Account> getAllAccounts() {
    if (_currentCompanyFile == null) return [];
    return List.unmodifiable(_currentCompanyFile!.accounts);
  }

  /// Gets all general journal entries
  List<GeneralJournal> getAllGeneralJournalEntries() {
    if (_currentCompanyFile == null) return [];
    return List.unmodifiable(_currentCompanyFile!.generalJournal);
  }

  /// Gets all suppliers
  List<SupplierModel> getAllSuppliers() {
    if (_currentCompanyFile == null) return [];
    return List.unmodifiable(_currentCompanyFile!.suppliers);
  }

  /// Gets all accounting rules
  List<AccountingRule> getAllAccountingRules() {
    if (_currentCompanyFile == null) return [];
    return List.unmodifiable(_currentCompanyFile!.accountingRules);
  }

  /// Gets the company profile
  CompanyProfile? getCompanyProfile() {
    return _currentCompanyFile?.profile;
  }

  /// Validates the current company file
  List<String> validate() {
    if (_currentCompanyFile == null) {
      return ['No company file loaded'];
    }
    return _currentCompanyFile!.validate();
  }

  /// Exports the company file to individual files (for backward compatibility)
  ///
  /// This method allows existing code to continue working while
  /// the migration to the unified format is in progress.
  bool exportToIndividualFiles({
    String? accountsPath,
    String? generalJournalPath,
    String? companyProfilePath,
    String? accountingRulesPath,
    String? supplierListPath,
  }) {
    if (_testMode) {
      print('🛡️ TEST MODE: Skipping export operation');
      return true;
    }

    if (_currentCompanyFile == null) {
      print('❌ No company file loaded to export');
      return false;
    }

    try {
      // Set default paths if not provided
      accountsPath ??= 'inputs/accounts.json';
      generalJournalPath ??= 'data/general_journal.json';
      companyProfilePath ??= 'inputs/company_profile.txt';
      accountingRulesPath ??= 'inputs/accounting_rules.txt';
      supplierListPath ??= 'inputs/supplier_list.json';

      // Export accounts
      final accountsJson = jsonEncode(
          _currentCompanyFile!.accounts.map((a) => a.toJson()).toList());
      File(accountsPath).writeAsStringSync(accountsJson);

      // Export general journal
      final journalJson = jsonEncode(
          _currentCompanyFile!.generalJournal.map((g) => g.toJson()).toList());
      File(generalJournalPath).writeAsStringSync(journalJson);

      // Export company profile
      final profileText =
          _exportCompanyProfileToText(_currentCompanyFile!.profile);
      File(companyProfilePath).writeAsStringSync(profileText);

      // Export accounting rules
      final rulesText =
          _exportAccountingRulesToText(_currentCompanyFile!.accountingRules);
      File(accountingRulesPath).writeAsStringSync(rulesText);

      // Export suppliers
      final suppliersJson = jsonEncode(
          _currentCompanyFile!.suppliers.map((s) => s.toJson()).toList());
      File(supplierListPath).writeAsStringSync(suppliersJson);

      print('✅ Exported company file to individual files');
      return true;
    } catch (e) {
      print('❌ Error exporting to individual files: $e');
      return false;
    }
  }

  /// Exports company profile to text format
  String _exportCompanyProfileToText(CompanyProfile profile) {
    final buffer = StringBuffer();

    buffer.writeln('Company Name: ${profile.name}');
    buffer.writeln('Industry: ${profile.industry}');
    buffer.writeln('Location: ${profile.location}');
    buffer.writeln('Founder: ${profile.founder}');
    buffer.writeln('Mission: ${profile.mission}');
    buffer.writeln('');
    buffer.writeln('Products:');
    for (final product in profile.products) {
      buffer.writeln('- $product');
    }
    buffer.writeln('');
    buffer.writeln('Key Purchases for Operations:');
    for (final purchase in profile.keyPurchases) {
      buffer.writeln('1. $purchase');
    }
    buffer.writeln('');
    buffer.writeln('Sustainability Practices:');
    for (final practice in profile.sustainabilityPractices) {
      buffer.writeln('- $practice');
    }
    buffer.writeln('');
    buffer.writeln('Community & Values:');
    for (final value in profile.communityValues) {
      buffer.writeln('- $value');
    }
    buffer.writeln('');
    buffer.writeln('Unique Selling Points:');
    for (final point in profile.uniqueSellingPoints) {
      buffer.writeln('- $point');
    }
    buffer.writeln('');
    buffer.writeln('Accounting Considerations:');
    for (final consideration in profile.accountingConsiderations) {
      buffer.writeln('- $consideration');
    }

    return buffer.toString();
  }

  /// Exports accounting rules to text format
  String _exportAccountingRulesToText(List<AccountingRule> rules) {
    final buffer = StringBuffer();

    for (final rule in rules) {
      buffer.writeln('=== ACCOUNTING RULE: ${rule.name} ===');
      buffer.writeln('Created: ${rule.createdAt.toIso8601String()}');
      buffer.writeln('Priority: ${rule.priority} (1=lowest, 10=highest)');
      buffer.writeln('Condition: ${rule.condition}');
      buffer.writeln('Action: ${rule.action}');
      buffer.writeln('Account Code: ${rule.accountCode} (${rule.accountType})');
      buffer.writeln('Account Type: ${rule.accountType}');
      buffer.writeln('GST Handling: ${rule.gstHandling}');
      buffer.writeln('Notes: ${rule.notes}');
      buffer.writeln('');
    }

    return buffer.toString();
  }
}

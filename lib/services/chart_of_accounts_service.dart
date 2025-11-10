import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/models/account.dart';
import 'package:path/path.dart' as p;

/// Service that provides access to chart of accounts data
class ChartOfAccountsService {
  /// Creates a chart-of-accounts service that reads from [inputsDirectory] or
  /// falls back to the project `inputs/` directory (overridable via
  /// `AI_ACCOUNTING_INPUTS_DIR`).
  ChartOfAccountsService({String? inputsDirectory})
      : _inputsDirectory = inputsDirectory ??
            Platform.environment['AI_ACCOUNTING_INPUTS_DIR'] ??
            'inputs' {
    loadAccounts();
  }

  final String _inputsDirectory;

  /// Map of account code to Account object for quick lookups
  final Map<String, Account> accounts = {};

  /// Flag indicating if data has been loaded
  bool _isLoaded = false;

  String get _accountsFilePath => p.join(_inputsDirectory, 'accounts.json');

  /// Loads accounts from the JSON file
  ///
  /// Returns true if successful, false otherwise
  bool loadAccounts() {
    if (_isLoaded) return true;

    try {
      final file = File(_accountsFilePath);
      final jsonString = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;

      for (final jsonMap in jsonList) {
        final account = Account.fromJson(jsonMap as Map<String, dynamic>);
        accounts[account.code] = account;
      }

      _isLoaded = true;
      return true;
    } catch (e) {
      print('Error loading accounts: $e');
      return false;
    }
  }

  /// Get an account by its code
  ///
  /// Returns null if the account doesn't exist
  Account? getAccount(String code) {
    return accounts[code];
  }

  /// Get all accounts
  List<Account> getAllAccounts() {
    return accounts.values.toList();
  }

  /// Get accounts filtered by type
  List<Account> getAccountsByType(AccountType type) {
    return accounts.values.where((account) => account.type == type).toList();
  }

  /// Adds a new account to the chart of accounts
  ///
  /// Returns true if successful, false otherwise
  /// Throws exception if account code already exists or is in protected range
  bool addAccount(Account newAccount) {
    // Check if account code already exists
    if (accounts.containsKey(newAccount.code)) {
      throw Exception('Account code ${newAccount.code} already exists');
    }

    // 🛡️ **SECURITY CHECK**: Prevent bank account creation (001-099)
    final codeNum = int.tryParse(newAccount.code);
    if (codeNum != null && codeNum >= 1 && codeNum <= 99) {
      throw Exception(
          'Cannot create account in protected bank range (001-099): ${newAccount.code}');
    }

    // Add to memory
    accounts[newAccount.code] = newAccount;

    // Save to file
    return saveAccounts();
  }

  /// Saves all accounts to the JSON file
  ///
  /// Returns true if successful, false otherwise
  bool saveAccounts() {
    try {
      final file = File(_accountsFilePath);

      // Convert accounts to list and sort by account code
      final accountsList = accounts.values.toList();
      accountsList.sort((a, b) => a.code.compareTo(b.code));

      // Convert to JSON
      final jsonString =
          jsonEncode(accountsList.map((a) => a.toJson()).toList());

      // Write to file with pretty formatting
      final prettyJsonString = _formatJson(jsonString);
      file.writeAsStringSync(prettyJsonString);

      return true;
    } catch (e) {
      print('Error saving accounts: $e');
      return false;
    }
  }

  /// Formats JSON string with proper indentation for readability
  String _formatJson(String jsonString) {
    try {
      final dynamic jsonData = jsonDecode(jsonString);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonData);
    } catch (e) {
      // If formatting fails, return original string
      return jsonString;
    }
  }

  /// Validates that an account code is available
  bool isAccountCodeAvailable(String code) {
    return !accounts.containsKey(code);
  }

  /// Gets the next available account code in a range
  ///
  /// For example, if you want the next available code starting from 320,
  /// it will return 320 if available, otherwise 321, 322, etc.
  String getNextAvailableAccountCode(int startingCode) {
    int code = startingCode;
    while (accounts.containsKey(code.toString().padLeft(3, '0'))) {
      code++;
    }
    return code.toString().padLeft(3, '0');
  }
}

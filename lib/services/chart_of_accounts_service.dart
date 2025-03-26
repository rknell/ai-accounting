import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/models/account.dart';

/// Service that provides access to chart of accounts data
class ChartOfAccountsService {
  /// Map of account code to Account object for quick lookups
  final Map<String, Account> accounts = {};

  /// Flag indicating if data has been loaded
  bool _isLoaded = false;

  /// Default constructor
  ChartOfAccountsService() {
    loadAccounts();
  }

  /// Loads accounts from the JSON file
  ///
  /// Returns true if successful, false otherwise
  bool loadAccounts() {
    if (_isLoaded) return true;

    try {
      final file = File('inputs/accounts.json');
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
}

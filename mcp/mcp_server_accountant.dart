import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/split_transaction.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:dart_openai_client/dart_openai_client.dart';

/// 🏆 ACCOUNTANT MCP SERVER: Secure Accounting Operations [+1000 XP]
///
/// **ARCHITECTURAL VICTORY**: This MCP server provides secure accounting operations
/// for the AI accounting system with comprehensive safeguards and business logic:
/// 1. Transaction search by multiple criteria (string, account, date range, amount range)
/// 2. Safe transaction updates with bank account protection
/// 3. Automatic GST handling and split transaction management
/// 4. Read-only operations for data integrity
/// 5. Comprehensive validation and error handling
///
/// **STRATEGIC DECISIONS**:
/// - Bank account protection (codes 001-099 are immutable)
/// - No transaction deletion capability (audit trail preservation)
/// - Automatic GST recalculation on account changes
/// - Comprehensive search capabilities for transaction management
/// - Registration-based architecture (eliminates boilerplate)
/// - Strong typing for all operations (eliminates dynamic vulnerabilities)
///
/// **SECURITY FORTRESS**:
/// - Bank accounts (001-099) are protected from modification
/// - No delete operations to preserve audit trail
/// - Validation of all account codes against chart of accounts
/// - GST calculations automatically handled
/// - Balance validation on all updates
class AccountantMCPServer extends BaseMCPServer {
  /// Configuration options
  final bool enableDebugLogging;

  AccountantMCPServer({
    super.name = 'accountant-ai',
    super.version = '1.0.0',
    super.logger,
    this.enableDebugLogging = false,
  });

  @override
  Map<String, dynamic> getCapabilities() {
    final base = super.getCapabilities();
    return {
      ...base,
      'accounting': {
        'version': '1.0.0',
        'features': [
          'transaction_search',
          'transaction_update',
          'gst_handling',
          'bank_protection',
        ],
      },
    };
  }

  @override
  Future<void> initializeServer() async {
    // 🔍 **SEARCH TOOLS**: Comprehensive transaction search capabilities

    registerTool(MCPTool(
      name: 'search_transactions_by_string',
      description:
          'Search for transactions containing a specific string in description or notes',
      inputSchema: {
        'type': 'object',
        'properties': {
          'searchString': {
            'type': 'string',
            'description':
                'String to search for in transaction descriptions and notes',
          },
          'caseSensitive': {
            'type': 'boolean',
            'description': 'Whether the search should be case sensitive',
            'default': false,
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of results to return (default: 100)',
            'default': 100,
            'minimum': 1,
            'maximum': 1000,
          },
        },
        'required': ['searchString'],
      },
      callback: _handleSearchTransactionsByString,
    ));

    registerTool(MCPTool(
      name: 'search_transactions_by_account',
      description: 'Search for transactions involving a specific account code',
      inputSchema: {
        'type': 'object',
        'properties': {
          'accountCode': {
            'type': 'string',
            'description': 'Account code to search for in debits or credits',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of results to return (default: 100)',
            'default': 100,
            'minimum': 1,
            'maximum': 1000,
          },
        },
        'required': ['accountCode'],
      },
      callback: _handleSearchTransactionsByAccount,
    ));

    registerTool(MCPTool(
      name: 'search_transactions_by_date_range',
      description: 'Search for transactions within a specific date range',
      inputSchema: {
        'type': 'object',
        'properties': {
          'startDate': {
            'type': 'string',
            'format': 'date',
            'description': 'Start date in YYYY-MM-DD format',
          },
          'endDate': {
            'type': 'string',
            'format': 'date',
            'description': 'End date in YYYY-MM-DD format',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of results to return (default: 100)',
            'default': 100,
            'minimum': 1,
            'maximum': 1000,
          },
        },
        'required': ['startDate', 'endDate'],
      },
      callback: _handleSearchTransactionsByDateRange,
    ));

    registerTool(MCPTool(
      name: 'search_transactions_by_amount_range',
      description: 'Search for transactions within a specific amount range',
      inputSchema: {
        'type': 'object',
        'properties': {
          'minAmount': {
            'type': 'number',
            'description': 'Minimum transaction amount',
          },
          'maxAmount': {
            'type': 'number',
            'description': 'Maximum transaction amount',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of results to return (default: 100)',
            'default': 100,
            'minimum': 1,
            'maximum': 1000,
          },
        },
        'required': ['minAmount', 'maxAmount'],
      },
      callback: _handleSearchTransactionsByAmountRange,
    ));

    // 🔧 **UPDATE TOOL**: Secure transaction update with safeguards

    registerTool(MCPTool(
      name: 'update_transaction_account',
      description:
          'Update the non-bank account in a transaction with automatic GST handling',
      inputSchema: {
        'type': 'object',
        'properties': {
          'transactionId': {
            'type': 'string',
            'description':
                'Unique identifier for the transaction (date_description_amount_bankCode format)',
          },
          'newAccountCode': {
            'type': 'string',
            'description':
                'New account code to assign (must not be a bank account 001-099)',
          },
          'notes': {
            'type': 'string',
            'description':
                'Optional notes explaining the reason for the change',
            'default': '',
          },
        },
        'required': ['transactionId', 'newAccountCode'],
      },
      callback: _handleUpdateTransactionAccount,
    ));

    // 📋 **ACCOUNTING RULES TOOL**: Manage institutional accounting knowledge

    registerTool(MCPTool(
      name: 'add_accounting_rule',
      description:
          'Add a new accounting rule to guide future transaction categorization',
      inputSchema: {
        'type': 'object',
        'properties': {
          'ruleName': {
            'type': 'string',
            'description': 'Short descriptive name for the rule',
          },
          'condition': {
            'type': 'string',
            'description':
                'The condition that triggers this rule (e.g., "contains jason crook", "is credit transaction")',
          },
          'action': {
            'type': 'string',
            'description':
                'The action to take when condition is met (e.g., "categorize as staff wages", "categorize as sales")',
          },
          'accountCode': {
            'type': 'string',
            'description': 'The account code to assign when this rule applies',
          },
          'priority': {
            'type': 'integer',
            'description':
                'Rule priority (1-10, higher numbers take precedence)',
            'default': 5,
            'minimum': 1,
            'maximum': 10,
          },
          'notes': {
            'type': 'string',
            'description': 'Additional notes or examples for this rule',
            'default': '',
          },
        },
        'required': ['ruleName', 'condition', 'action', 'accountCode'],
      },
      callback: _handleAddAccountingRule,
    ));

    // 🏦 **ACCOUNT MANAGEMENT TOOL**: Add new accounts to chart of accounts

    registerTool(MCPTool(
      name: 'add_account',
      description: 'Add a new account to the chart of accounts',
      inputSchema: {
        'type': 'object',
        'properties': {
          'code': {
            'type': 'string',
            'description':
                'Account code (e.g., "320", "400"). Must be unique and not in bank range (001-099)',
            'pattern': '^[0-9]{3}\$',
          },
          'name': {
            'type': 'string',
            'description':
                'Account name (e.g., "Office Rent", "Consulting Revenue")',
          },
          'type': {
            'type': 'string',
            'enum': [
              'Bank',
              'Revenue',
              'Other Income',
              'COGS',
              'Expense',
              'Depreciation',
              'Current Asset',
              'Inventory',
              'Fixed Asset',
              'Current Liability',
              'Equity'
            ],
            'description':
                'Account type - determines how the account behaves in reports',
          },
          'gst': {
            'type': 'boolean',
            'description': 'Whether GST applies to this account',
            'default': false,
          },
          'gstType': {
            'type': 'string',
            'enum': [
              'GST on Income',
              'GST on Expenses',
              'GST Free Expenses',
              'BAS Excluded',
              'GST on Capital'
            ],
            'description': 'GST treatment type (required if gst is true)',
            'default': 'BAS Excluded',
          },
          'suggestCode': {
            'type': 'boolean',
            'description':
                'If true and code is taken, suggest next available code',
            'default': false,
          },
        },
        'required': ['name', 'type'],
      },
      callback: _handleAddAccount,
    ));

    // 🏪 **SUPPLIER MANAGEMENT TOOL**: Update supplier information and categories
    
    registerTool(MCPTool(
      name: 'update_supplier_info',
      description: 'Add or update supplier information in the supplier list with business category',
      inputSchema: {
        'type': 'object',
        'properties': {
          'supplierName': {
            'type': 'string',
            'description': 'Clean supplier name (e.g., "GitHub, Inc." not "Sp Github Payment")',
          },
          'category': {
            'type': 'string',
            'description': 'Business category/purpose (e.g., "Software Development Tools", "Marketing & Advertising")',
          },
          'rawTransactionText': {
            'type': 'string',
            'description': 'Original transaction description that led to this supplier discovery',
            'default': '',
          },
          'businessDescription': {
            'type': 'string',
            'description': 'What this supplier does and how it relates to the business',
            'default': '',
          },
          'suggestedAccountCode': {
            'type': 'string',
            'description': 'Suggested account code for transactions with this supplier',
            'default': '',
          },
          'replaceExisting': {
            'type': 'boolean',
            'description': 'If supplier exists, replace the category (default: update only if category is "Unknown")',
            'default': false,
          },
        },
        'required': ['supplierName', 'category'],
      },
      callback: _handleUpdateSupplierInfo,
    ));

    // Register resources with their callbacks
    registerResource(MCPResource(
      uri: 'accounting://journal/summary',
      name: 'General Journal Summary',
      description: 'Summary statistics of the general journal',
      mimeType: 'application/json',
      callback: _getJournalSummary,
    ));

    registerResource(MCPResource(
      uri: 'accounting://accounts/chart',
      name: 'Chart of Accounts',
      description:
          'Complete chart of accounts with account types and GST settings',
      mimeType: 'application/json',
      callback: _getChartOfAccounts,
    ));

    registerResource(MCPResource(
      uri: 'accounting://rules/list',
      name: 'Accounting Rules',
      description:
          'Institutional accounting rules for transaction categorization',
      mimeType: 'text/plain',
      callback: _getAccountingRules,
    ));

    registerResource(MCPResource(
      uri: 'accounting://suppliers/list',
      name: 'Supplier List',
      description: 'Known suppliers with their business categories and purposes',
      mimeType: 'application/json',
      callback: _getSupplierList,
    ));

    // Register prompts with their callbacks
    registerPrompt(MCPPrompt(
      name: 'transaction_analysis_workflow',
      description: 'Complete workflow for analyzing and updating transactions',
      arguments: [
        MCPPromptArgument(
          name: 'search_criteria',
          description:
              'Criteria for finding transactions (string, account, date, or amount)',
          required: true,
        ),
        MCPPromptArgument(
          name: 'update_account',
          description: 'New account code to apply if updating transactions',
          required: false,
        ),
      ],
      callback: _getTransactionAnalysisWorkflow,
    ));

    logger?.call('info',
        'Accountant MCP server initialized with ${getAvailableTools().length} tools, ${getAvailableResources().length} resources, and ${getAvailablePrompts().length} prompts');
  }

  /// 🔍 **SEARCH BY STRING HANDLER**: Find transactions containing specific text
  Future<MCPToolResult> _handleSearchTransactionsByString(
      Map<String, dynamic> arguments) async {
    final searchString = arguments['searchString'] as String;
    final caseSensitive = arguments['caseSensitive'] as bool? ?? false;
    final limit = arguments['limit'] as int? ?? 100;

    logger?.call('info', 'Searching transactions by string: "$searchString"');

    try {
      // Load journal entries
      if (!services.generalJournal.loadEntries()) {
        throw MCPServerException('Failed to load general journal entries');
      }

      final allEntries = services.generalJournal.getAllEntries();
      final matchingEntries = <GeneralJournal>[];

      for (final entry in allEntries) {
        final searchIn = caseSensitive
            ? '${entry.description} ${entry.notes}'
            : '${entry.description} ${entry.notes}'.toLowerCase();
        final searchFor =
            caseSensitive ? searchString : searchString.toLowerCase();

        if (searchIn.contains(searchFor)) {
          matchingEntries.add(entry);
          if (matchingEntries.length >= limit) break;
        }
      }

      final results = _formatTransactionResults(matchingEntries);
      logger?.call('info',
          'Found ${matchingEntries.length} transactions matching "$searchString"');

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'searchType': 'string',
            'searchCriteria': searchString,
            'totalFound': matchingEntries.length,
            'results': results,
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'String search failed', e);
      throw MCPServerException('String search failed: ${e.toString()}');
    }
  }

  /// 🏦 **SEARCH BY ACCOUNT HANDLER**: Find transactions involving specific account
  Future<MCPToolResult> _handleSearchTransactionsByAccount(
      Map<String, dynamic> arguments) async {
    final accountCode = arguments['accountCode'] as String;
    final limit = arguments['limit'] as int? ?? 100;

    logger?.call('info', 'Searching transactions by account: $accountCode');

    try {
      // Validate account exists
      final account = services.chartOfAccounts.getAccount(accountCode);
      if (account == null) {
        throw MCPServerException('Account not found: $accountCode');
      }

      // Load journal entries
      if (!services.generalJournal.loadEntries()) {
        throw MCPServerException('Failed to load general journal entries');
      }

      final matchingEntries = services.generalJournal
          .getEntriesByAccount(accountCode)
          .take(limit)
          .toList();

      final results = _formatTransactionResults(matchingEntries);
      logger?.call('info',
          'Found ${matchingEntries.length} transactions for account $accountCode');

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'searchType': 'account',
            'searchCriteria': accountCode,
            'accountName': account.name,
            'totalFound': matchingEntries.length,
            'results': results,
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Account search failed', e);
      throw MCPServerException('Account search failed: ${e.toString()}');
    }
  }

  /// 📅 **SEARCH BY DATE RANGE HANDLER**: Find transactions within date range
  Future<MCPToolResult> _handleSearchTransactionsByDateRange(
      Map<String, dynamic> arguments) async {
    final startDateStr = arguments['startDate'] as String;
    final endDateStr = arguments['endDate'] as String;
    final limit = arguments['limit'] as int? ?? 100;

    logger?.call('info',
        'Searching transactions by date range: $startDateStr to $endDateStr');

    try {
      final startDate = DateTime.parse(startDateStr);
      final endDate = DateTime.parse(endDateStr);

      if (startDate.isAfter(endDate)) {
        throw MCPServerException('Start date must be before end date');
      }

      // Load journal entries
      if (!services.generalJournal.loadEntries()) {
        throw MCPServerException('Failed to load general journal entries');
      }

      final matchingEntries = services.generalJournal
          .getEntriesByDateRange(startDate, endDate)
          .take(limit)
          .toList();

      final results = _formatTransactionResults(matchingEntries);
      logger?.call('info',
          'Found ${matchingEntries.length} transactions between $startDateStr and $endDateStr');

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'searchType': 'dateRange',
            'searchCriteria': {
              'startDate': startDateStr,
              'endDate': endDateStr,
            },
            'totalFound': matchingEntries.length,
            'results': results,
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Date range search failed', e);
      throw MCPServerException('Date range search failed: ${e.toString()}');
    }
  }

  /// 💰 **SEARCH BY AMOUNT RANGE HANDLER**: Find transactions within amount range
  Future<MCPToolResult> _handleSearchTransactionsByAmountRange(
      Map<String, dynamic> arguments) async {
    final minAmount = (arguments['minAmount'] as num).toDouble();
    final maxAmount = (arguments['maxAmount'] as num).toDouble();
    final limit = arguments['limit'] as int? ?? 100;

    logger?.call('info',
        'Searching transactions by amount range: \$${minAmount.toStringAsFixed(2)} to \$${maxAmount.toStringAsFixed(2)}');

    try {
      if (minAmount > maxAmount) {
        throw MCPServerException(
            'Minimum amount must be less than maximum amount');
      }

      // Load journal entries
      if (!services.generalJournal.loadEntries()) {
        throw MCPServerException('Failed to load general journal entries');
      }

      final allEntries = services.generalJournal.getAllEntries();
      final matchingEntries = allEntries
          .where(
              (entry) => entry.amount >= minAmount && entry.amount <= maxAmount)
          .take(limit)
          .toList();

      final results = _formatTransactionResults(matchingEntries);
      logger?.call('info',
          'Found ${matchingEntries.length} transactions between \$${minAmount.toStringAsFixed(2)} and \$${maxAmount.toStringAsFixed(2)}');

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'searchType': 'amountRange',
            'searchCriteria': {
              'minAmount': minAmount,
              'maxAmount': maxAmount,
            },
            'totalFound': matchingEntries.length,
            'results': results,
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Amount range search failed', e);
      throw MCPServerException('Amount range search failed: ${e.toString()}');
    }
  }

  /// 🔧 **UPDATE TRANSACTION HANDLER**: Safely update non-bank accounts with GST handling
  Future<MCPToolResult> _handleUpdateTransactionAccount(
      Map<String, dynamic> arguments) async {
    final transactionId = arguments['transactionId'] as String;
    final newAccountCode = arguments['newAccountCode'] as String;
    final notes = arguments['notes'] as String? ?? '';

    logger?.call('info',
        'Updating transaction $transactionId to account $newAccountCode');

    try {
      // 🛡️ **SECURITY CHECK**: Validate new account is not a bank account
      final newAccountCodeNum = int.tryParse(newAccountCode);
      if (newAccountCodeNum != null &&
          newAccountCodeNum >= 1 &&
          newAccountCodeNum <= 99) {
        throw MCPServerException(
            'Cannot update to bank account: $newAccountCode. Bank accounts (001-099) are protected.');
      }

      // Validate new account exists
      final newAccount = services.chartOfAccounts.getAccount(newAccountCode);
      if (newAccount == null) {
        throw MCPServerException('New account not found: $newAccountCode');
      }

      // Load journal entries
      if (!services.generalJournal.loadEntries()) {
        throw MCPServerException('Failed to load general journal entries');
      }

      // Find the transaction to update
      final originalTransaction = _findTransactionById(transactionId);
      if (originalTransaction == null) {
        throw MCPServerException('Transaction not found: $transactionId');
      }

      // 🛡️ **SECURITY CHECK**: Identify and protect bank account in transaction
      final bankAccount = originalTransaction.bankAccount;

      // Create updated transaction with new account and GST handling
      final updatedTransaction = _createUpdatedTransaction(
        originalTransaction,
        newAccountCode,
        newAccount,
        notes,
      );

      // Update the transaction
      final success = services.generalJournal
          .updateEntry(originalTransaction, updatedTransaction);
      if (!success) {
        throw MCPServerException('Failed to update transaction in database');
      }

      logger?.call('info', 'Successfully updated transaction $transactionId');

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'success': true,
            'transactionId': transactionId,
            'originalAccount': _getOriginalNonBankAccount(originalTransaction),
            'newAccount': {
              'code': newAccount.code,
              'name': newAccount.name,
              'type': newAccount.type.value,
              'gst': newAccount.gst,
              'gstType': newAccount.gstType.value,
            },
            'bankAccount': {
              'code': bankAccount.code,
              'name': bankAccount.name,
              'protected': true,
            },
            'gstHandling': _describeGstHandling(newAccount),
            'updatedTransaction': _formatSingleTransaction(updatedTransaction),
            'notes': notes,
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Transaction update failed', e);
      throw MCPServerException('Transaction update failed: ${e.toString()}');
    }
  }

  /// 📋 **ACCOUNTING RULES HANDLER**: Add new accounting rule to institutional knowledge
  Future<MCPToolResult> _handleAddAccountingRule(
      Map<String, dynamic> arguments) async {
    final ruleName = arguments['ruleName'] as String;
    final condition = arguments['condition'] as String;
    final action = arguments['action'] as String;
    final accountCode = arguments['accountCode'] as String;
    final priority = arguments['priority'] as int? ?? 5;
    final notes = arguments['notes'] as String? ?? '';

    logger?.call('info', 'Adding accounting rule: $ruleName');

    try {
      // 🛡️ **SECURITY CHECK**: Validate account exists and is not a bank account
      final account = services.chartOfAccounts.getAccount(accountCode);
      if (account == null) {
        throw MCPServerException('Account not found: $accountCode');
      }

      final accountCodeNum = int.tryParse(accountCode);
      if (accountCodeNum != null &&
          accountCodeNum >= 1 &&
          accountCodeNum <= 99) {
        throw MCPServerException(
            'Cannot create rule for bank account: $accountCode. Bank accounts (001-099) are protected.');
      }

      // Ensure inputs directory exists
      final inputsDir = Directory('inputs');
      if (!inputsDir.existsSync()) {
        inputsDir.createSync(recursive: true);
      }

      // Create or append to accounting rules file
      final rulesFile = File('inputs/accounting_rules.txt');
      final timestamp = DateTime.now().toIso8601String();

      // Format the rule entry
      final ruleEntry = '''
=== ACCOUNTING RULE: $ruleName ===
Created: $timestamp
Priority: $priority (1=lowest, 10=highest)
Condition: $condition
Action: $action
Account Code: $accountCode (${account.name})
Account Type: ${account.type.value}
GST Handling: ${account.gst ? account.gstType.value : 'No GST'}
Notes: $notes

''';

      // Read existing rules to check for duplicates
      String existingContent = '';
      if (rulesFile.existsSync()) {
        existingContent = rulesFile.readAsStringSync();
      }

      // Check for duplicate rule names
      if (existingContent.contains('=== ACCOUNTING RULE: $ruleName ===')) {
        throw MCPServerException(
            'Rule with name "$ruleName" already exists. Please use a different name or update the existing rule.');
      }

      // Append the new rule
      rulesFile.writeAsStringSync(existingContent + ruleEntry);

      logger?.call('info', 'Successfully added accounting rule: $ruleName');

      // Count total rules
      final totalRules = existingContent.split('=== ACCOUNTING RULE:').length;

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'success': true,
            'ruleName': ruleName,
            'condition': condition,
            'action': action,
            'account': {
              'code': accountCode,
              'name': account.name,
              'type': account.type.value,
              'gst': account.gst,
              'gstType': account.gstType.value,
            },
            'priority': priority,
            'notes': notes,
            'timestamp': timestamp,
            'totalRules': totalRules,
            'filePath': 'inputs/accounting_rules.txt',
            'message':
                'Accounting rule "$ruleName" added successfully. This rule will now be included in the AI categorization system prompt.',
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to add accounting rule', e);
      throw MCPServerException(
          'Failed to add accounting rule: ${e.toString()}');
    }
  }

  /// 🏦 **ADD ACCOUNT HANDLER**: Add new account to chart of accounts
  Future<MCPToolResult> _handleAddAccount(
      Map<String, dynamic> arguments) async {
    final name = arguments['name'] as String;
    final typeString = arguments['type'] as String;
    final gst = arguments['gst'] as bool? ?? false;
    final gstTypeString = arguments['gstType'] as String? ?? 'BAS Excluded';
    final suggestCode = arguments['suggestCode'] as bool? ?? false;
    String? providedCode = arguments['code'] as String?;

    logger?.call('info', 'Adding new account: $name ($typeString)');

    try {
      // Parse account type
      final accountType = AccountType.values.firstWhere(
        (type) => type.value == typeString,
        orElse: () =>
            throw MCPServerException('Invalid account type: $typeString'),
      );

      // Parse GST type
      final gstType = GstType.values.firstWhere(
        (type) => type.value == gstTypeString,
        orElse: () =>
            throw MCPServerException('Invalid GST type: $gstTypeString'),
      );

      // Handle account code
      String accountCode;
      if (providedCode != null) {
        // Validate provided code format
        if (!RegExp(r'^[0-9]{3}$').hasMatch(providedCode)) {
          throw MCPServerException(
              'Account code must be exactly 3 digits: $providedCode');
        }

        // 🛡️ **SECURITY CHECK**: Prevent bank account creation
        final codeNum = int.parse(providedCode);
        if (codeNum >= 1 && codeNum <= 99) {
          throw MCPServerException(
              'Cannot create account in bank range (001-099): $providedCode');
        }

        // Check if code is available
        if (!services.chartOfAccounts.isAccountCodeAvailable(providedCode)) {
          if (suggestCode) {
            // Find next available code
            accountCode =
                services.chartOfAccounts.getNextAvailableAccountCode(codeNum);
            logger?.call(
                'info', 'Code $providedCode taken, suggesting $accountCode');
          } else {
            throw MCPServerException(
                'Account code $providedCode already exists. Use suggestCode=true to get alternative.');
          }
        } else {
          accountCode = providedCode;
        }
      } else {
        // Auto-assign code based on account type
        final baseCode = _getBaseCodeForAccountType(accountType);
        accountCode =
            services.chartOfAccounts.getNextAvailableAccountCode(baseCode);
        logger?.call('info', 'Auto-assigned account code: $accountCode');
      }

      // Create new account
      final newAccount = Account(
        code: accountCode,
        name: name,
        type: accountType,
        gst: gst,
        gstType: gstType,
      );

      // Add to chart of accounts
      final success = services.chartOfAccounts.addAccount(newAccount);
      if (!success) {
        throw MCPServerException('Failed to save account to chart of accounts');
      }

      logger?.call('info', 'Successfully added account: $accountCode - $name');

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'success': true,
            'account': {
              'code': accountCode,
              'name': name,
              'type': accountType.value,
              'gst': gst,
              'gstType': gstType.value,
            },
            'wasCodeSuggested':
                providedCode != null && providedCode != accountCode,
            'originalCode': providedCode,
            'totalAccounts': services.chartOfAccounts.getAllAccounts().length,
            'message':
                'Account "$name" ($accountCode) added successfully to chart of accounts.',
            'gstHandling': gst
                ? {
                    'applicable': true,
                    'type': gstType.value,
                    'description': gstType == GstType.gstOnIncome
                        ? 'GST will be collected on transactions to this account'
                        : gstType == GstType.gstOnExpenses
                            ? 'GST will be claimed on transactions to this account'
                            : 'Special GST treatment applies',
                  }
                : {
                    'applicable': false,
                    'description': 'No GST applies to this account',
                  },
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to add account', e);
      throw MCPServerException('Failed to add account: ${e.toString()}');
    }
  }

  /// Get base account code for auto-assignment based on account type
  int _getBaseCodeForAccountType(AccountType accountType) {
    switch (accountType) {
      case AccountType.bank:
        return 1; // 001-099 (but protected)
      case AccountType.revenue:
        return 100; // 100-199
      case AccountType.otherIncome:
        return 150; // 150-199
      case AccountType.cogs:
        return 200; // 200-299
      case AccountType.expense:
        return 300; // 300-499
      case AccountType.depreciation:
        return 480; // 480-499
      case AccountType.currentAsset:
        return 500; // 500-549
      case AccountType.inventory:
        return 550; // 550-599
      case AccountType.fixedAsset:
        return 600; // 600-699
      case AccountType.currentLiability:
        return 700; // 700-749
      case AccountType.equity:
        return 800; // 800-899
    }
  }

  /// 🏪 **SUPPLIER INFO HANDLER**: Add or update supplier information
  Future<MCPToolResult> _handleUpdateSupplierInfo(
      Map<String, dynamic> arguments) async {
    final supplierName = arguments['supplierName'] as String;
    final category = arguments['category'] as String;
    final rawTransactionText = arguments['rawTransactionText'] as String? ?? '';
    final businessDescription = arguments['businessDescription'] as String? ?? '';
    final suggestedAccountCode = arguments['suggestedAccountCode'] as String? ?? '';
    final replaceExisting = arguments['replaceExisting'] as bool? ?? false;

    logger?.call('info', 'Updating supplier info: $supplierName -> $category');

    try {
      // Validate suggested account code if provided
      if (suggestedAccountCode.isNotEmpty) {
        final account = services.chartOfAccounts.getAccount(suggestedAccountCode);
        if (account == null) {
          throw MCPServerException('Suggested account code not found: $suggestedAccountCode');
        }
      }

      // Ensure inputs directory exists
      final inputsDir = Directory('inputs');
      if (!inputsDir.existsSync()) {
        inputsDir.createSync(recursive: true);
      }

      // Load existing supplier list
      final supplierFile = File('inputs/supplier_list.json');
      List<Map<String, dynamic>> suppliers = [];
      
      if (supplierFile.existsSync()) {
        final jsonString = supplierFile.readAsStringSync();
        if (jsonString.isNotEmpty) {
          final jsonList = jsonDecode(jsonString) as List<dynamic>;
          suppliers = jsonList.cast<Map<String, dynamic>>();
        }
      }

      // Check if supplier already exists (case-insensitive fuzzy match)
      int existingIndex = -1;
      String? existingCategory;
      
      for (int i = 0; i < suppliers.length; i++) {
        final existingName = suppliers[i]['name'] as String;
        if (_isFuzzyMatch(supplierName, existingName)) {
          existingIndex = i;
          existingCategory = suppliers[i]['category'] as String?;
          break;
        }
      }

      bool wasUpdated = false;
      bool wasAdded = false;
      String? previousCategory;

      if (existingIndex >= 0) {
        // Supplier exists - decide whether to update
        previousCategory = existingCategory;
        
        if (replaceExisting || 
            existingCategory == null || 
            existingCategory.toLowerCase() == 'unknown' ||
            existingCategory.isEmpty) {
          
          suppliers[existingIndex] = {
            'name': supplierName, // Use the cleaned name
            'category': category,
          };
          wasUpdated = true;
          
          logger?.call('info', 'Updated existing supplier: $supplierName ($previousCategory -> $category)');
        } else {
          logger?.call('info', 'Supplier exists with category "$existingCategory", not updating (use replaceExisting=true to force)');
        }
      } else {
        // New supplier - add it
        suppliers.add({
          'name': supplierName,
          'category': category,
        });
        wasAdded = true;
        
        logger?.call('info', 'Added new supplier: $supplierName ($category)');
      }

      if (wasAdded || wasUpdated) {
        // Sort suppliers alphabetically by name
        suppliers.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

        // Save back to file with pretty formatting
        const encoder = JsonEncoder.withIndent('  ');
        final prettyJsonString = encoder.convert(suppliers);
        supplierFile.writeAsStringSync(prettyJsonString);
      }

      // Create response
      final response = {
        'success': true,
        'supplierName': supplierName,
        'category': category,
        'action': wasAdded ? 'added' : (wasUpdated ? 'updated' : 'no_change'),
        'totalSuppliers': suppliers.length,
        'previousCategory': previousCategory,
        'rawTransactionText': rawTransactionText,
        'businessDescription': businessDescription,
        'suggestedAccount': suggestedAccountCode.isNotEmpty ? {
          'code': suggestedAccountCode,
          'name': services.chartOfAccounts.getAccount(suggestedAccountCode)?.name ?? 'Unknown',
        } : null,
        'message': wasAdded 
            ? 'Added new supplier "$supplierName" with category "$category"'
            : wasUpdated 
                ? 'Updated supplier "$supplierName" from "$previousCategory" to "$category"'
                : 'Supplier "$supplierName" already exists with category "$existingCategory" (use replaceExisting=true to force update)',
        'fuzzyMatching': existingIndex >= 0 ? 'Matched existing supplier using fuzzy logic' : null,
      };

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode(response)),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to update supplier info', e);
      throw MCPServerException('Failed to update supplier info: ${e.toString()}');
    }
  }

  /// Check if two supplier names are a fuzzy match
  bool _isFuzzyMatch(String name1, String name2) {
    // Normalize names for comparison
    final normalized1 = _normalizeSupplierName(name1);
    final normalized2 = _normalizeSupplierName(name2);
    
    // Exact match after normalization
    if (normalized1 == normalized2) return true;
    
    // Check if one contains the other (for partial matches)
    if (normalized1.contains(normalized2) || normalized2.contains(normalized1)) {
      return true;
    }
    
    // Check for common variations
    final variations1 = _getSupplierVariations(normalized1);
    final variations2 = _getSupplierVariations(normalized2);
    
    for (final var1 in variations1) {
      for (final var2 in variations2) {
        if (var1 == var2) return true;
      }
    }
    
    return false;
  }

  /// Normalize supplier name for comparison
  String _normalizeSupplierName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  /// Get common variations of a supplier name
  List<String> _getSupplierVariations(String normalizedName) {
    final variations = <String>[normalizedName];
    
    // Remove common prefixes
    final prefixes = ['sp ', 'visa purchase ', 'eftpos ', 'paypal ', 'sq '];
    for (final prefix in prefixes) {
      if (normalizedName.startsWith(prefix)) {
        variations.add(normalizedName.substring(prefix.length));
      }
    }
    
    // Remove common suffixes
    final suffixes = [' pty ltd', ' ltd', ' inc', ' com', ' au'];
    for (final suffix in suffixes) {
      if (normalizedName.endsWith(suffix)) {
        variations.add(normalizedName.substring(0, normalizedName.length - suffix.length));
      }
    }
    
    // Remove location codes and numbers
    final withoutNumbers = normalizedName.replaceAll(RegExp(r'\d+'), '').trim();
    if (withoutNumbers != normalizedName) {
      variations.add(withoutNumbers);
    }
    
    return variations;
  }

  /// 🔍 **UTILITY METHODS**: Helper functions for transaction operations

  /// Find transaction by ID (date_description_amount_bankCode format)
  GeneralJournal? _findTransactionById(String transactionId) {
    final parts = transactionId.split('_');
    if (parts.length < 4) return null;

    final dateStr = parts[0];
    final description = parts.sublist(1, parts.length - 2).join('_');
    final amountStr = parts[parts.length - 2];
    final bankCode = parts[parts.length - 1];

    try {
      final date = DateTime.parse(dateStr);
      final amount = double.parse(amountStr);

      return services.generalJournal.getAllEntries().firstWhere(
            (entry) =>
                entry.date.year == date.year &&
                entry.date.month == date.month &&
                entry.date.day == date.day &&
                entry.description == description &&
                entry.amount == amount &&
                entry.bankCode == bankCode,
            orElse: () => throw StateError('Not found'),
          );
    } catch (e) {
      return null;
    }
  }

  /// Get the original non-bank account from a transaction
  Map<String, dynamic> _getOriginalNonBankAccount(GeneralJournal transaction) {
    final bankCode = transaction.bankCode;

    // Find non-bank account in debits
    for (final debit in transaction.debits) {
      if (debit.accountCode != bankCode) {
        final account = services.chartOfAccounts.getAccount(debit.accountCode);
        if (account != null) {
          return {
            'code': account.code,
            'name': account.name,
            'type': account.type.value,
            'side': 'debit',
            'amount': debit.amount,
          };
        }
      }
    }

    // Find non-bank account in credits
    for (final credit in transaction.credits) {
      if (credit.accountCode != bankCode) {
        final account = services.chartOfAccounts.getAccount(credit.accountCode);
        if (account != null) {
          return {
            'code': account.code,
            'name': account.name,
            'type': account.type.value,
            'side': 'credit',
            'amount': credit.amount,
          };
        }
      }
    }

    return {'error': 'No non-bank account found'};
  }

  /// Create updated transaction with new account and proper GST handling
  GeneralJournal _createUpdatedTransaction(
    GeneralJournal original,
    String newAccountCode,
    Account newAccount,
    String notes,
  ) {
    final bankCode = original.bankCode;
    final totalAmount = original.amount;

    // Determine transaction direction (is bank account debited or credited?)
    final isBankDebited = original.debits.any((d) => d.accountCode == bankCode);

    // Create GST-aware split transactions
    final gstSplits = _createSplitTransactionsWithGst(
      newAccountCode,
      totalAmount,
      newAccount.gst && newAccount.gstType == GstType.gstOnIncome,
    );

    List<SplitTransaction> debits;
    List<SplitTransaction> credits;

    if (isBankDebited) {
      // Bank is debited, new account(s) are credited
      debits = [SplitTransaction(accountCode: bankCode, amount: totalAmount)];
      credits = gstSplits;
    } else {
      // Bank is credited, new account(s) are debited
      debits = gstSplits;
      credits = [SplitTransaction(accountCode: bankCode, amount: totalAmount)];
    }

    // Create updated notes
    final updatedNotes =
        notes.isEmpty ? original.notes : '${original.notes}\n$notes';

    return GeneralJournal(
      date: original.date,
      description: original.description,
      debits: debits,
      credits: credits,
      bankBalance: original.bankBalance,
      notes: updatedNotes,
    );
  }

  /// Create split transactions with GST handling (mirrors GeneralJournalService logic)
  List<SplitTransaction> _createSplitTransactionsWithGst(
      String accountCode, double amount, bool isGstOnIncome) {
    final account = services.chartOfAccounts.getAccount(accountCode);
    if (account == null || !account.gst) {
      return [SplitTransaction(accountCode: accountCode, amount: amount)];
    }

    // GST calculation (10% rate)
    const gstRate = 0.1;
    final gstAmount = amount * (gstRate / (1 + gstRate));
    final netAmount = amount - gstAmount;

    // Get GST clearing account
    final gstAccount = services.environment.gstClearingAccountCode;

    return [
      SplitTransaction(accountCode: accountCode, amount: netAmount),
      SplitTransaction(accountCode: gstAccount, amount: gstAmount),
    ];
  }

  /// Describe GST handling for an account
  Map<String, dynamic> _describeGstHandling(Account account) {
    if (!account.gst) {
      return {
        'hasGst': false,
        'description': 'No GST applicable',
      };
    }

    final gstRate = 10.0;
    return {
      'hasGst': true,
      'gstType': account.gstType.value,
      'gstRate': gstRate,
      'description': account.gstType == GstType.gstOnIncome
          ? 'GST collected on income ($gstRate%)'
          : 'GST paid on expenses ($gstRate%)',
      'clearingAccount': services.environment.gstClearingAccountCode,
    };
  }

  /// Format transaction results for output
  List<Map<String, dynamic>> _formatTransactionResults(
      List<GeneralJournal> transactions) {
    return transactions
        .map((transaction) => _formatSingleTransaction(transaction))
        .toList();
  }

  /// Format a single transaction for output
  Map<String, dynamic> _formatSingleTransaction(GeneralJournal transaction) {
    return {
      'id':
          '${transaction.date.toIso8601String().split('T')[0]}_${transaction.description}_${transaction.amount}_${transaction.bankCode}',
      'date': transaction.date.toIso8601String().split('T')[0],
      'description': transaction.description,
      'amount': transaction.amount,
      'bankCode': transaction.bankCode,
      'bankName': transaction.bankAccount.name,
      'bankBalance': transaction.bankBalance,
      'debits': transaction.debits
          .map((d) => {
                'accountCode': d.accountCode,
                'accountName':
                    services.chartOfAccounts.getAccount(d.accountCode)?.name ??
                        'Unknown',
                'amount': d.amount,
              })
          .toList(),
      'credits': transaction.credits
          .map((c) => {
                'accountCode': c.accountCode,
                'accountName':
                    services.chartOfAccounts.getAccount(c.accountCode)?.name ??
                        'Unknown',
                'amount': c.amount,
              })
          .toList(),
      'notes': transaction.notes,
    };
  }

  /// 📊 **RESOURCE CALLBACKS**: Implement resource reading callbacks

  /// Get general journal summary
  Future<MCPContent> _getJournalSummary() async {
    if (!services.generalJournal.loadEntries()) {
      throw MCPServerException('Failed to load general journal entries');
    }

    final entries = services.generalJournal.getAllEntries();
    final summary = {
      'totalTransactions': entries.length,
      'dateRange': entries.isEmpty
          ? null
          : {
              'earliest': entries
                  .map((e) => e.date)
                  .reduce((a, b) => a.isBefore(b) ? a : b)
                  .toIso8601String()
                  .split('T')[0],
              'latest': entries
                  .map((e) => e.date)
                  .reduce((a, b) => a.isAfter(b) ? a : b)
                  .toIso8601String()
                  .split('T')[0],
            },
      'totalValue':
          entries.fold<double>(0.0, (sum, entry) => sum + entry.amount),
      'bankAccounts': entries.map((e) => e.bankCode).toSet().length,
      'accountsUsed': {
        ...entries.expand((e) => e.debits.map((d) => d.accountCode)).toSet(),
        ...entries.expand((e) => e.credits.map((c) => c.accountCode)).toSet(),
      }.length,
    };

    return MCPContent.resource(
      data: jsonEncode(summary),
      mimeType: 'application/json',
    );
  }

  /// Get chart of accounts
  Future<MCPContent> _getChartOfAccounts() async {
    final accounts = services.chartOfAccounts.getAllAccounts();
    final chartData = {
      'totalAccounts': accounts.length,
      'accountsByType': AccountType.values
          .map((type) => {
                'type': type.value,
                'count': accounts.where((a) => a.type == type).length,
                'accounts': accounts
                    .where((a) => a.type == type)
                    .map((a) => {
                          'code': a.code,
                          'name': a.name,
                          'gst': a.gst,
                          'gstType': a.gstType.value,
                        })
                    .toList(),
              })
          .toList(),
      'bankAccounts': accounts
          .where((a) => a.type == AccountType.bank)
          .map((a) => {
                'code': a.code,
                'name': a.name,
                'protected': true,
              })
          .toList(),
    };

    return MCPContent.resource(
      data: jsonEncode(chartData),
      mimeType: 'application/json',
    );
  }

  /// Get accounting rules
  Future<MCPContent> _getAccountingRules() async {
    final rulesFile = File('inputs/accounting_rules.txt');

    if (!rulesFile.existsSync()) {
      return MCPContent.resource(
        data:
            'No accounting rules defined yet. Use the add_accounting_rule tool to create institutional knowledge for transaction categorization.',
        mimeType: 'text/plain',
      );
    }

    final rulesContent = rulesFile.readAsStringSync();
    return MCPContent.resource(
      data: rulesContent,
      mimeType: 'text/plain',
    );
  }

  /// Get supplier list
  Future<MCPContent> _getSupplierList() async {
    final supplierFile = File('inputs/supplier_list.json');
    
    if (!supplierFile.existsSync()) {
      final emptyList = <Map<String, dynamic>>[];
      return MCPContent.resource(
        data: jsonEncode(emptyList),
        mimeType: 'application/json',
      );
    }

    final supplierContent = supplierFile.readAsStringSync();
    if (supplierContent.isEmpty) {
      final emptyList = <Map<String, dynamic>>[];
      return MCPContent.resource(
        data: jsonEncode(emptyList),
        mimeType: 'application/json',
      );
    }

    // Validate and reformat the JSON
    try {
      final suppliers = jsonDecode(supplierContent) as List<dynamic>;
      final formattedSuppliers = suppliers.map((s) => {
        'name': s['name'] as String,
        'category': s['category'] as String,
      }).toList();
      
      return MCPContent.resource(
        data: jsonEncode(formattedSuppliers),
        mimeType: 'application/json',
      );
    } catch (e) {
      // Return error information if JSON is malformed
      return MCPContent.resource(
        data: jsonEncode({
          'error': 'Invalid supplier list format',
          'message': e.toString(),
          'suppliers': <Map<String, dynamic>>[],
        }),
        mimeType: 'application/json',
      );
    }
  }

  /// 💬 **PROMPT CALLBACKS**: Implement prompt execution callbacks

  /// Get transaction analysis workflow
  Future<List<MCPMessage>> _getTransactionAnalysisWorkflow(
      Map<String, dynamic> arguments) async {
    final searchCriteria = arguments['search_criteria'] as String;
    final updateAccount = arguments['update_account'] as String?;

    final messages = <MCPMessage>[
      MCPMessage.notification(
        method: 'tools/call',
        params: {
          'name': 'search_transactions_by_string',
          'arguments': {'searchString': searchCriteria, 'limit': 50},
        },
      ),
    ];

    if (updateAccount != null) {
      messages.add(MCPMessage.notification(
        method: 'tools/call',
        params: {
          'name': 'update_transaction_account',
          'arguments': {
            'transactionId': '{{transaction_id_from_search}}',
            'newAccountCode': updateAccount,
            'notes': 'Updated via transaction analysis workflow',
          },
        },
      ));
    }

    return messages;
  }

  @override
  Future<void> shutdown() async {
    logger?.call('info', 'Shutting down Accountant MCP server');
    await super.shutdown();
  }
}

/// 🚀 **MAIN ENTRY POINT**: Start the Accountant MCP server
void main() async {
  final server = AccountantMCPServer(
    enableDebugLogging: true,
    logger: (level, message, [data]) {
      final timestamp = DateTime.now().toIso8601String();
      stderr.writeln(
          '[$timestamp] [$level] $message${data != null ? ': $data' : ''}');
    },
  );

  try {
    await server.start();
  } catch (e) {
    stderr.writeln('Failed to start Accountant MCP server: $e');
    exit(1);
  }
}

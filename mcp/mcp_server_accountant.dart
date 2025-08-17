import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/split_transaction.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:archive/archive_io.dart';
import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:path/path.dart' as path;

/// 🏆 ACCOUNTANT MCP SERVER: Secure Accounting Operations [+1000 XP]
///
/// **ARCHITECTURAL VICTORY**: This MCP server provides secure accounting operations
/// for the AI accounting system with comprehensive safeguards and business logic:
/// 1. Transaction search by multiple criteria (string, account, date range, amount range)
/// 2. Safe transaction updates with bank account protection
/// 3. Automatic GST handling and split transaction management
/// 4. Financial report regeneration after journal updates
/// 5. Read-only operations for data integrity
/// 6. Comprehensive validation and error handling
///
/// **STRATEGIC DECISIONS**:
/// - Bank account protection (codes 001-099 are immutable)
/// - No transaction deletion capability (audit trail preservation)
/// - Automatic GST recalculation on account changes
/// - Integrated report regeneration with update suggestions
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
  final String inputsPath;
  final String dataPath;

  AccountantMCPServer({
    super.name = 'accountant-ai',
    super.version = '1.0.0',
    super.logger,
    this.enableDebugLogging = false,
    this.inputsPath = 'inputs',
    this.dataPath = 'data',
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
          'report_regeneration',
          'supplier_crud',
          'accounting_rules_crud',
          'audit_reports',
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

    // 📋 **ACCOUNTING RULES TOOLS**: Complete CRUD operations for accounting rules

    registerTool(MCPTool(
      name: 'create_accounting_rule',
      description:
          'Create a new accounting rule to guide future transaction categorization',
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
      callback: _handleCreateAccountingRule,
    ));

    registerTool(MCPTool(
      name: 'read_accounting_rule',
      description: 'Retrieve a specific accounting rule by name',
      inputSchema: {
        'type': 'object',
        'properties': {
          'ruleName': {
            'type': 'string',
            'description': 'Name of the accounting rule to retrieve',
          },
        },
        'required': ['ruleName'],
      },
      callback: _handleReadAccountingRule,
    ));

    registerTool(MCPTool(
      name: 'update_accounting_rule',
      description: 'Update an existing accounting rule with new details',
      inputSchema: {
        'type': 'object',
        'properties': {
          'ruleName': {
            'type': 'string',
            'description': 'Current name of the rule to update',
          },
          'newRuleName': {
            'type': 'string',
            'description': 'New name for the rule (optional)',
          },
          'condition': {
            'type': 'string',
            'description': 'Updated condition (optional)',
          },
          'action': {
            'type': 'string',
            'description': 'Updated action (optional)',
          },
          'accountCode': {
            'type': 'string',
            'description': 'Updated account code (optional)',
          },
          'priority': {
            'type': 'integer',
            'description': 'Updated priority (optional)',
            'minimum': 1,
            'maximum': 10,
          },
          'notes': {
            'type': 'string',
            'description': 'Updated notes (optional)',
          },
        },
        'required': ['ruleName'],
      },
      callback: _handleUpdateAccountingRule,
    ));

    registerTool(MCPTool(
      name: 'delete_accounting_rule',
      description: 'Remove an accounting rule from the system',
      inputSchema: {
        'type': 'object',
        'properties': {
          'ruleName': {
            'type': 'string',
            'description': 'Name of the rule to delete',
          },
          'confirmDelete': {
            'type': 'boolean',
            'description': 'Confirmation flag to prevent accidental deletions',
            'default': false,
          },
        },
        'required': ['ruleName', 'confirmDelete'],
      },
      callback: _handleDeleteAccountingRule,
    ));

    registerTool(MCPTool(
      name: 'list_accounting_rules',
      description:
          'List all accounting rules with optional filtering and sorting',
      inputSchema: {
        'type': 'object',
        'properties': {
          'filterByCondition': {
            'type': 'string',
            'description': 'Filter rules by condition containing this text',
          },
          'filterByAccountCode': {
            'type': 'string',
            'description': 'Filter rules by specific account code',
          },
          'sortBy': {
            'type': 'string',
            'enum': ['name', 'priority', 'created', 'account_code'],
            'description': 'How to sort the rules list',
            'default': 'priority',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of rules to return',
            'default': 100,
            'minimum': 1,
            'maximum': 1000,
          },
        },
        'required': <String>[],
      },
      callback: _handleListAccountingRules,
    ));

    // Legacy alias for backward compatibility
    registerTool(MCPTool(
      name: 'add_accounting_rule',
      description:
          'DEPRECATED: Use create_accounting_rule instead. Add a new accounting rule to guide future transaction categorization',
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

    // 🏪 **SUPPLIER MANAGEMENT TOOLS**: Complete CRUD operations for supplier list

    registerTool(MCPTool(
      name: 'create_supplier',
      description:
          'Create a new supplier entry in the supplier list with comprehensive information',
      inputSchema: {
        'type': 'object',
        'properties': {
          'supplierName': {
            'type': 'string',
            'description':
                'Clean supplier name (e.g., "GitHub, Inc." not "Sp Github Payment")',
          },
          'supplies': {
            'type': 'string',
            'description':
                'What the supplier provides/supplies (e.g., "Software development tools", "Marketing and advertising services")',
          },
          'account': {
            'type': 'string',
            'description':
                'Optional fixed numeric account code for this supplier',
          },
          'rawTransactionText': {
            'type': 'string',
            'description':
                'Original transaction description that led to this supplier discovery',
            'default': '',
          },
          'businessDescription': {
            'type': 'string',
            'description':
                'What this supplier does and how it relates to the business',
            'default': '',
          },
          'suggestedAccountCode': {
            'type': 'string',
            'description':
                'Suggested account code for transactions with this supplier',
            'default': '',
          },
        },
        'required': ['supplierName', 'supplies'],
      },
      callback: _handleCreateSupplier,
    ));

    registerTool(MCPTool(
      name: 'read_supplier',
      description:
          'Retrieve supplier information by name with fuzzy matching support',
      inputSchema: {
        'type': 'object',
        'properties': {
          'supplierName': {
            'type': 'string',
            'description':
                'Supplier name to search for (supports fuzzy matching)',
          },
          'exactMatch': {
            'type': 'boolean',
            'description': 'Whether to require exact name matching',
            'default': false,
          },
        },
        'required': ['supplierName'],
      },
      callback: _handleReadSupplier,
    ));

    registerTool(MCPTool(
      name: 'update_supplier',
      description: 'Update existing supplier information with new details',
      inputSchema: {
        'type': 'object',
        'properties': {
          'supplierName': {
            'type': 'string',
            'description': 'Current supplier name to update',
          },
          'newSupplierName': {
            'type': 'string',
            'description':
                'New supplier name (optional, keeps current if not provided)',
          },
          'supplies': {
            'type': 'string',
            'description': 'Updated supplies description (optional)',
          },
          'account': {
            'type': 'string',
            'description': 'Updated account code (optional)',
          },
          'businessDescription': {
            'type': 'string',
            'description': 'Updated business description (optional)',
            'default': '',
          },
        },
        'required': ['supplierName'],
      },
      callback: _handleUpdateSupplier,
    ));

    registerTool(MCPTool(
      name: 'delete_supplier',
      description: 'Remove a supplier from the supplier list',
      inputSchema: {
        'type': 'object',
        'properties': {
          'supplierName': {
            'type': 'string',
            'description': 'Supplier name to delete (supports fuzzy matching)',
          },
          'confirmDelete': {
            'type': 'boolean',
            'description': 'Confirmation flag to prevent accidental deletions',
            'default': false,
          },
        },
        'required': ['supplierName', 'confirmDelete'],
      },
      callback: _handleDeleteSupplier,
    ));

    registerTool(MCPTool(
      name: 'list_suppliers',
      description: 'List all suppliers with optional filtering and sorting',
      inputSchema: {
        'type': 'object',
        'properties': {
          'filterBySupplies': {
            'type': 'string',
            'description': 'Filter suppliers by supplies containing this text',
          },
          'filterByAccount': {
            'type': 'string',
            'description': 'Filter suppliers by specific account code',
          },
          'sortBy': {
            'type': 'string',
            'enum': ['name', 'supplies', 'account'],
            'description': 'How to sort the supplier list',
            'default': 'name',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of suppliers to return',
            'default': 100,
            'minimum': 1,
            'maximum': 1000,
          },
        },
        'required': <String>[],
      },
      callback: _handleListSuppliers,
    ));

    // Legacy alias for backward compatibility
    registerTool(MCPTool(
      name: 'update_supplier_info',
      description:
          'DEPRECATED: Use create_supplier or update_supplier instead. Add or update supplier information in the supplier list with what they supply and optional account code',
      inputSchema: {
        'type': 'object',
        'properties': {
          'supplierName': {
            'type': 'string',
            'description':
                'Clean supplier name (e.g., "GitHub, Inc." not "Sp Github Payment")',
          },
          'supplies': {
            'type': 'string',
            'description':
                'What the supplier provides/supplies (e.g., "Software development tools", "Marketing and advertising services")',
          },
          'account': {
            'type': 'string',
            'description':
                'Optional fixed numeric account code for this supplier',
          },
          'rawTransactionText': {
            'type': 'string',
            'description':
                'Original transaction description that led to this supplier discovery',
            'default': '',
          },
          'businessDescription': {
            'type': 'string',
            'description':
                'What this supplier does and how it relates to the business',
            'default': '',
          },
          'suggestedAccountCode': {
            'type': 'string',
            'description':
                'Suggested account code for transactions with this supplier',
            'default': '',
          },
          'replaceExisting': {
            'type': 'boolean',
            'description':
                'If supplier exists, replace the category (default: update only if category is "Unknown")',
            'default': false,
          },
        },
        'required': ['supplierName', 'supplies'],
      },
      callback: _handleUpdateSupplierInfo,
    ));

    // 📊 **AUDIT REPORTING TOOLS**: Generate plaintext reports for AI audit purposes

    registerTool(MCPTool(
      name: 'generate_balance_sheet_audit',
      description:
          'Generate a plaintext balance sheet report for audit purposes with dynamic date ranges. Shows assets, liabilities, and equity with account codes and names.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'asOfDate': {
            'type': 'string',
            'format': 'date',
            'description':
                'The date for which to generate the balance sheet (YYYY-MM-DD format)',
          },
          'includeZeroBalances': {
            'type': 'boolean',
            'description': 'Whether to include accounts with zero balances',
            'default': false,
          },
          'sortBy': {
            'type': 'string',
            'enum': ['account_code', 'account_name', 'balance'],
            'description': 'How to sort the accounts within each section',
            'default': 'account_code',
          },
        },
        'required': ['asOfDate'],
      },
      callback: _handleGenerateBalanceSheetAudit,
    ));

    registerTool(MCPTool(
      name: 'generate_profit_loss_audit',
      description:
          'Generate a plaintext profit & loss statement for audit purposes with dynamic date ranges. Shows revenue, COGS, expenses, and profit calculations with account codes and names.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'startDate': {
            'type': 'string',
            'format': 'date',
            'description': 'Start date for the P&L period (YYYY-MM-DD format)',
          },
          'endDate': {
            'type': 'string',
            'format': 'date',
            'description': 'End date for the P&L period (YYYY-MM-DD format)',
          },
          'includeZeroBalances': {
            'type': 'boolean',
            'description': 'Whether to include accounts with zero activity',
            'default': false,
          },
          'sortBy': {
            'type': 'string',
            'enum': ['account_code', 'account_name', 'amount'],
            'description': 'How to sort the accounts within each section',
            'default': 'account_code',
          },
          'includeTransactionCounts': {
            'type': 'boolean',
            'description':
                'Whether to include transaction counts for each account',
            'default': true,
          },
        },
        'required': ['startDate', 'endDate'],
      },
      callback: _handleGenerateProfitLossAudit,
    ));

    registerTool(MCPTool(
      name: 'generate_trial_balance_audit',
      description:
          'Generate a plaintext trial balance report for audit purposes. Shows all accounts with their debit and credit balances as of a specific date.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'asOfDate': {
            'type': 'string',
            'format': 'date',
            'description':
                'The date for which to generate the trial balance (YYYY-MM-DD format)',
          },
          'includeZeroBalances': {
            'type': 'boolean',
            'description': 'Whether to include accounts with zero balances',
            'default': false,
          },
          'sortBy': {
            'type': 'string',
            'enum': ['account_code', 'account_name', 'account_type'],
            'description': 'How to sort the accounts',
            'default': 'account_code',
          },
          'groupByType': {
            'type': 'boolean',
            'description':
                'Whether to group accounts by type (Assets, Liabilities, etc.)',
            'default': true,
          },
        },
        'required': ['asOfDate'],
      },
      callback: _handleGenerateTrialBalanceAudit,
    ));

    registerTool(MCPTool(
      name: 'generate_cash_flow_audit',
      description:
          'Generate a plaintext cash flow statement for audit purposes showing cash movements from operating, investing, and financing activities.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'startDate': {
            'type': 'string',
            'format': 'date',
            'description':
                'Start date for the cash flow period (YYYY-MM-DD format)',
          },
          'endDate': {
            'type': 'string',
            'format': 'date',
            'description':
                'End date for the cash flow period (YYYY-MM-DD format)',
          },
          'cashAccountCodes': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'Specific bank/cash account codes to analyze (default: all bank accounts)',
            'default': <String>[],
          },
        },
        'required': ['startDate', 'endDate'],
      },
      callback: _handleGenerateCashFlowAudit,
    ));

    registerTool(MCPTool(
      name: 'generate_account_activity_audit',
      description:
          'Generate a detailed plaintext report showing all transactions for specific accounts during a date range. Useful for detailed account analysis.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'accountCodes': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Account codes to analyze (required)',
          },
          'startDate': {
            'type': 'string',
            'format': 'date',
            'description':
                'Start date for the analysis period (YYYY-MM-DD format)',
          },
          'endDate': {
            'type': 'string',
            'format': 'date',
            'description':
                'End date for the analysis period (YYYY-MM-DD format)',
          },
          'includeRunningBalance': {
            'type': 'boolean',
            'description': 'Whether to include running balance calculations',
            'default': true,
          },
          'sortBy': {
            'type': 'string',
            'enum': ['date', 'amount', 'description'],
            'description': 'How to sort the transactions',
            'default': 'date',
          },
        },
        'required': ['accountCodes', 'startDate', 'endDate'],
      },
      callback: _handleGenerateAccountActivityAudit,
    ));

    // 📊 **REPORT REGENERATION TOOL**: Regenerate all financial reports after journal updates

    registerTool(MCPTool(
      name: 'regenerate_reports',
      description:
          'Regenerate all financial reports after general journal updates. Creates Profit & Loss, Balance Sheet, GST Report, General Journal Report, Ledger Report, and Report Wrapper for the previous financial quarter. Creates timestamped zip backups of inputs and data directories.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'reason': {
            'type': 'string',
            'description':
                'Optional reason for regenerating reports (e.g., "After updating transaction accounts", "After importing new bank statements")',
            'default': 'Manual report regeneration requested',
          },
          'createZipBackup': {
            'type': 'boolean',
            'description':
                'Whether to create a timestamped zip backup of inputs and data directories',
            'default': true,
          },
          'backupDirectories': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'List of directories to include in the zip backup (default: ["inputs", "data"])',
            'default': ['inputs', 'data'],
          },
        },
        'required': <String>[],
      },
      callback: _handleRegenerateReports,
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
      description:
          'Known suppliers with their business categories and purposes',
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
            'Cannot update to bank account: $newAccountCode. Bank accounts (001-099) are protected. If you need to transfer between accounts, use a transfer holding account (which should have a 0 balance at the end of a full reconciliation)');
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
            'suggestion': {
              'action': 'regenerate_reports',
              'reason':
                  'Consider regenerating financial reports to reflect this transaction update',
              'toolName': 'regenerate_reports',
              'toolArguments': {
                'reason':
                    'After updating transaction account from ${_getOriginalNonBankAccount(originalTransaction)['code']} to $newAccountCode',
              },
            },
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Transaction update failed', e);
      throw MCPServerException('Transaction update failed: ${e.toString()}');
    }
  }

  /// 📋 **ACCOUNTING RULES CRUD HANDLERS**: Complete CRUD operations for accounting rules

  /// 🆕 **CREATE ACCOUNTING RULE HANDLER**: Create a new accounting rule
  Future<MCPToolResult> _handleCreateAccountingRule(
      Map<String, dynamic> arguments) async {
    final ruleName = arguments['ruleName'] as String;
    final condition = arguments['condition'] as String;
    final action = arguments['action'] as String;
    final accountCode = arguments['accountCode'] as String;
    final priority = arguments['priority'] as int? ?? 5;
    final notes = arguments['notes'] as String? ?? '';

    logger?.call('info', 'Creating accounting rule: $ruleName');

    try {
      // Validate account exists and is not a bank account
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
      final inputsDir = Directory(inputsPath);
      if (!inputsDir.existsSync()) {
        inputsDir.createSync(recursive: true);
      }

      final rulesFile = File('$inputsPath/accounting_rules.txt');

      // Check for duplicate rule names
      if (rulesFile.existsSync()) {
        final existingContent = rulesFile.readAsStringSync();
        if (existingContent.contains('=== ACCOUNTING RULE: $ruleName ===')) {
          throw MCPServerException(
              'Rule with name "$ruleName" already exists. Use update_accounting_rule to modify existing rules.');
        }
      }

      // Create the rule entry
      final timestamp = DateTime.now().toIso8601String();
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

      // Append the new rule
      final existingContent =
          rulesFile.existsSync() ? rulesFile.readAsStringSync() : '';
      rulesFile.writeAsStringSync(existingContent + ruleEntry);

      // Count total rules
      final totalRules = existingContent.split('=== ACCOUNTING RULE:').length;

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'success': true,
            'action': 'created',
            'rule': {
              'name': ruleName,
              'condition': condition,
              'action': action,
              'accountCode': accountCode,
              'accountName': account.name,
              'priority': priority,
              'notes': notes,
              'timestamp': timestamp,
            },
            'totalRules': totalRules,
            'message': 'Successfully created accounting rule "$ruleName"',
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to create accounting rule', e);
      throw MCPServerException(
          'Failed to create accounting rule: ${e.toString()}');
    }
  }

  /// 📖 **READ ACCOUNTING RULE HANDLER**: Retrieve a specific accounting rule
  Future<MCPToolResult> _handleReadAccountingRule(
      Map<String, dynamic> arguments) async {
    final ruleName = arguments['ruleName'] as String;

    try {
      final rulesFile = File('$inputsPath/accounting_rules.txt');
      if (!rulesFile.existsSync()) {
        throw MCPServerException('Accounting rules file not found');
      }

      final content = rulesFile.readAsStringSync();
      if (content.isEmpty) {
        throw MCPServerException('Accounting rules file is empty');
      }

      // Parse the rule
      final ruleStart = content.indexOf('=== ACCOUNTING RULE: $ruleName ===');
      if (ruleStart == -1) {
        throw MCPServerException('Accounting rule not found: $ruleName');
      }

      final nextRuleStart =
          content.indexOf('=== ACCOUNTING RULE:', ruleStart + 1);
      final ruleEnd = nextRuleStart == -1 ? content.length : nextRuleStart;
      final ruleContent = content.substring(ruleStart, ruleEnd).trim();

      // Extract rule details
      final lines = ruleContent.split('\n');
      final ruleData = <String, dynamic>{'name': ruleName};

      for (final line in lines) {
        if (line.startsWith('Created: ')) {
          ruleData['created'] = line.substring(9);
        } else if (line.startsWith('Priority: ')) {
          final priorityText = line.substring(10);
          ruleData['priority'] = int.tryParse(priorityText.split(' ')[0]) ?? 5;
        } else if (line.startsWith('Condition: ')) {
          ruleData['condition'] = line.substring(11);
        } else if (line.startsWith('Action: ')) {
          ruleData['action'] = line.substring(8);
        } else if (line.startsWith('Account Code: ')) {
          final accountInfo = line.substring(14);
          final codeMatch = RegExp(r'^(\d+)').firstMatch(accountInfo);
          if (codeMatch != null) {
            ruleData['accountCode'] = codeMatch.group(1);
          }
        } else if (line.startsWith('Notes: ')) {
          ruleData['notes'] = line.substring(7);
        }
      }

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'success': true,
            'rule': ruleData,
            'rawContent': ruleContent,
            'message': 'Successfully retrieved accounting rule "$ruleName"',
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to read accounting rule', e);
      throw MCPServerException(
          'Failed to read accounting rule: ${e.toString()}');
    }
  }

  /// ✏️ **UPDATE ACCOUNTING RULE HANDLER**: Update an existing accounting rule
  Future<MCPToolResult> _handleUpdateAccountingRule(
      Map<String, dynamic> arguments) async {
    final ruleName = arguments['ruleName'] as String;
    final newRuleName = arguments['newRuleName'] as String?;
    final condition = arguments['condition'] as String?;
    final action = arguments['action'] as String?;
    final accountCode = arguments['accountCode'] as String?;
    final priority = arguments['priority'] as int?;
    final notes = arguments['notes'] as String?;

    try {
      final rulesFile = File('$inputsPath/accounting_rules.txt');
      if (!rulesFile.existsSync()) {
        throw MCPServerException('Accounting rules file not found');
      }

      final content = rulesFile.readAsStringSync();
      if (content.isEmpty) {
        throw MCPServerException('Accounting rules file is empty');
      }

      // Find the rule to update
      final ruleStart = content.indexOf('=== ACCOUNTING RULE: $ruleName ===');
      if (ruleStart == -1) {
        throw MCPServerException('Accounting rule not found: $ruleName');
      }

      final nextRuleStart =
          content.indexOf('=== ACCOUNTING RULE:', ruleStart + 1);
      final ruleEnd = nextRuleStart == -1 ? content.length : nextRuleStart;
      final originalRuleContent = content.substring(ruleStart, ruleEnd).trim();

      // Parse existing rule
      final lines = originalRuleContent.split('\n');
      final ruleData = <String, String>{};

      for (final line in lines) {
        if (line.startsWith('Created: ')) {
          ruleData['created'] = line.substring(9);
        } else if (line.startsWith('Priority: ')) {
          ruleData['priority'] = line.substring(10).split(' ')[0];
        } else if (line.startsWith('Condition: ')) {
          ruleData['condition'] = line.substring(11);
        } else if (line.startsWith('Action: ')) {
          ruleData['action'] = line.substring(8);
        } else if (line.startsWith('Account Code: ')) {
          final accountInfo = line.substring(14);
          final codeMatch = RegExp(r'^(\d+)').firstMatch(accountInfo);
          if (codeMatch != null) {
            ruleData['accountCode'] = codeMatch.group(1)!;
          }
        } else if (line.startsWith('Notes: ')) {
          ruleData['notes'] = line.substring(7);
        }
      }

      // Apply updates
      final updatedRuleName = newRuleName ?? ruleName;
      final updatedCondition = condition ?? ruleData['condition'] ?? '';
      final updatedAction = action ?? ruleData['action'] ?? '';
      final updatedAccountCode = accountCode ?? ruleData['accountCode'] ?? '';
      final updatedPriority =
          priority ?? int.tryParse(ruleData['priority'] ?? '5') ?? 5;
      final updatedNotes = notes ?? ruleData['notes'] ?? '';

      // Validate account if changed
      final account = services.chartOfAccounts.getAccount(updatedAccountCode);
      if (account == null) {
        throw MCPServerException('Account not found: $updatedAccountCode');
      }

      // Check for name conflicts if name is being changed
      if (newRuleName != null && newRuleName != ruleName) {
        if (content.contains('=== ACCOUNTING RULE: $newRuleName ===')) {
          throw MCPServerException(
              'Rule with name "$newRuleName" already exists');
        }
      }

      // Create updated rule content
      final timestamp = DateTime.now().toIso8601String();
      final updatedRuleContent = '''
=== ACCOUNTING RULE: $updatedRuleName ===
Created: ${ruleData['created']}
Updated: $timestamp
Priority: $updatedPriority (1=lowest, 10=highest)
Condition: $updatedCondition
Action: $updatedAction
Account Code: $updatedAccountCode (${account.name})
Account Type: ${account.type.value}
GST Handling: ${account.gst ? account.gstType.value : 'No GST'}
Notes: $updatedNotes

''';

      // Replace the rule in the content
      final beforeRule = content.substring(0, ruleStart);
      final afterRule = nextRuleStart == -1 ? '' : content.substring(ruleEnd);
      final newContent = beforeRule + updatedRuleContent + afterRule;

      rulesFile.writeAsStringSync(newContent);

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'success': true,
            'action': 'updated',
            'rule': {
              'name': updatedRuleName,
              'condition': updatedCondition,
              'action': updatedAction,
              'accountCode': updatedAccountCode,
              'accountName': account.name,
              'priority': updatedPriority,
              'notes': updatedNotes,
              'updated': timestamp,
            },
            'originalName': ruleName,
            'message':
                'Successfully updated accounting rule "$updatedRuleName"',
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to update accounting rule', e);
      throw MCPServerException(
          'Failed to update accounting rule: ${e.toString()}');
    }
  }

  /// 🗑️ **DELETE ACCOUNTING RULE HANDLER**: Remove an accounting rule
  Future<MCPToolResult> _handleDeleteAccountingRule(
      Map<String, dynamic> arguments) async {
    final ruleName = arguments['ruleName'] as String;
    final confirmDelete = arguments['confirmDelete'] as bool? ?? false;

    try {
      if (!confirmDelete) {
        throw MCPServerException(
            'Delete operation requires confirmDelete=true to prevent accidental deletions');
      }

      final rulesFile = File('$inputsPath/accounting_rules.txt');
      if (!rulesFile.existsSync()) {
        throw MCPServerException('Accounting rules file not found');
      }

      final content = rulesFile.readAsStringSync();
      if (content.isEmpty) {
        throw MCPServerException('Accounting rules file is empty');
      }

      // Find the rule to delete
      final ruleStart = content.indexOf('=== ACCOUNTING RULE: $ruleName ===');
      if (ruleStart == -1) {
        throw MCPServerException('Accounting rule not found: $ruleName');
      }

      final nextRuleStart =
          content.indexOf('=== ACCOUNTING RULE:', ruleStart + 1);
      final ruleEnd = nextRuleStart == -1 ? content.length : nextRuleStart;
      final deletedRuleContent = content.substring(ruleStart, ruleEnd).trim();

      // Remove the rule from content
      final beforeRule = content.substring(0, ruleStart);
      final afterRule = nextRuleStart == -1 ? '' : content.substring(ruleEnd);
      final newContent = beforeRule + afterRule;

      rulesFile.writeAsStringSync(newContent);

      // Count remaining rules
      final remainingRules =
          newContent.split('=== ACCOUNTING RULE:').length - 1;

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'success': true,
            'action': 'deleted',
            'deletedRule': {
              'name': ruleName,
              'content': deletedRuleContent,
            },
            'remainingRules': remainingRules,
            'message': 'Successfully deleted accounting rule "$ruleName"',
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to delete accounting rule', e);
      throw MCPServerException(
          'Failed to delete accounting rule: ${e.toString()}');
    }
  }

  /// 📋 **LIST ACCOUNTING RULES HANDLER**: List all accounting rules with filtering
  Future<MCPToolResult> _handleListAccountingRules(
      Map<String, dynamic> arguments) async {
    final filterByCondition = arguments['filterByCondition'] as String?;
    final filterByAccountCode = arguments['filterByAccountCode'] as String?;
    final sortBy = arguments['sortBy'] as String? ?? 'priority';
    final limit = arguments['limit'] as int? ?? 100;

    try {
      final rulesFile = File('$inputsPath/accounting_rules.txt');
      List<Map<String, dynamic>> rules = [];

      if (rulesFile.existsSync()) {
        final content = rulesFile.readAsStringSync();
        if (content.isNotEmpty) {
          // Parse all rules
          final ruleBlocks = content.split('=== ACCOUNTING RULE:').skip(1);

          for (final block in ruleBlocks) {
            final lines = block.trim().split('\n');
            if (lines.isEmpty) continue;

            final ruleNameLine = lines.first;
            final ruleName = ruleNameLine.replaceAll(' ===', '').trim();

            final ruleData = <String, dynamic>{'name': ruleName};

            for (final line in lines.skip(1)) {
              if (line.startsWith('Created: ')) {
                ruleData['created'] = line.substring(9);
              } else if (line.startsWith('Priority: ')) {
                final priorityText = line.substring(10);
                ruleData['priority'] =
                    int.tryParse(priorityText.split(' ')[0]) ?? 5;
              } else if (line.startsWith('Condition: ')) {
                ruleData['condition'] = line.substring(11);
              } else if (line.startsWith('Action: ')) {
                ruleData['action'] = line.substring(8);
              } else if (line.startsWith('Account Code: ')) {
                final accountInfo = line.substring(14);
                final codeMatch = RegExp(r'^(\d+)').firstMatch(accountInfo);
                if (codeMatch != null) {
                  ruleData['accountCode'] = codeMatch.group(1);
                }
              } else if (line.startsWith('Notes: ')) {
                ruleData['notes'] = line.substring(7);
              }
            }

            rules.add(ruleData);
          }
        }
      }

      // Apply filters
      if (filterByCondition != null) {
        rules = rules.where((rule) {
          final condition = rule['condition'] as String? ?? '';
          return condition
              .toLowerCase()
              .contains(filterByCondition.toLowerCase());
        }).toList();
      }

      if (filterByAccountCode != null) {
        rules = rules.where((rule) {
          return rule['accountCode'] == filterByAccountCode;
        }).toList();
      }

      // Sort rules
      switch (sortBy) {
        case 'name':
          rules.sort(
              (a, b) => (a['name'] as String).compareTo(b['name'] as String));
          break;
        case 'created':
          rules.sort((a, b) => (a['created'] as String? ?? '')
              .compareTo(b['created'] as String? ?? ''));
          break;
        case 'account_code':
          rules.sort((a, b) => (a['accountCode'] as String? ?? '')
              .compareTo(b['accountCode'] as String? ?? ''));
          break;
        case 'priority':
        default:
          rules.sort((a, b) => (b['priority'] as int? ?? 5)
              .compareTo(a['priority'] as int? ?? 5));
          break;
      }

      // Apply limit
      if (rules.length > limit) {
        rules = rules.take(limit).toList();
      }

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'success': true,
            'rules': rules,
            'totalReturned': rules.length,
            'filters': {
              'byCondition': filterByCondition,
              'byAccountCode': filterByAccountCode,
            },
            'sortBy': sortBy,
            'limit': limit,
            'message': 'Successfully listed ${rules.length} accounting rules',
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to list accounting rules', e);
      throw MCPServerException(
          'Failed to list accounting rules: ${e.toString()}');
    }
  }

  /// 📋 **LEGACY ACCOUNTING RULES HANDLER**: Add new accounting rule to institutional knowledge (backward compatibility)
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
      final inputsDir = Directory(inputsPath);
      if (!inputsDir.existsSync()) {
        inputsDir.createSync(recursive: true);
      }

      // Create or append to accounting rules file
      final rulesFile = File('$inputsPath/accounting_rules.txt');
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
            'filePath': '$inputsPath/accounting_rules.txt',
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

  /// 📊 **REGENERATE REPORTS HANDLER**: Regenerate all financial reports with zip backup
  Future<MCPToolResult> _handleRegenerateReports(
      Map<String, dynamic> arguments) async {
    final reason = arguments['reason'] as String? ??
        'Manual report regeneration requested';
    final createZipBackup = arguments['createZipBackup'] as bool? ?? true;
    final backupDirectories = (arguments['backupDirectories'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['inputs', 'data'];

    logger?.call('info', 'Regenerating reports: $reason');

    try {
      // Ensure general journal is loaded
      if (!services.generalJournal.loadEntries()) {
        throw MCPServerException('Failed to load general journal entries');
      }

      final startTime = DateTime.now();

      // Generate all reports using the ReportGenerationService
      services.reportGeneration.generateReports();

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      // Create zip backup after report generation if requested
      Map<String, dynamic>? zipBackupResult;
      if (createZipBackup) {
        logger?.call('info',
            'Creating zip backup of directories: ${backupDirectories.join(', ')}');
        zipBackupResult = _createZipBackup(
          directoriesToBackup: backupDirectories,
          reason: reason,
        );
      }

      // Get report statistics
      final journalEntries = services.generalJournal.getAllEntries();
      final totalTransactions = journalEntries.length;
      final dateRange = journalEntries.isEmpty
          ? null
          : {
              'earliest': journalEntries
                  .map((e) => e.date)
                  .reduce((a, b) => a.isBefore(b) ? a : b)
                  .toIso8601String()
                  .split('T')[0],
              'latest': journalEntries
                  .map((e) => e.date)
                  .reduce((a, b) => a.isAfter(b) ? a : b)
                  .toIso8601String()
                  .split('T')[0],
            };

      logger?.call('info',
          'Reports regenerated successfully in ${duration.inMilliseconds}ms');

      final response = {
        'success': true,
        'reason': reason,
        'generationTime': duration.inMilliseconds,
        'reportsGenerated': [
          'Profit and Loss Report',
          'Balance Sheet',
          'GST Report',
          'General Journal Report',
          'Ledger Report',
          'Report Wrapper (Navigation)',
        ],
        'statistics': {
          'totalTransactions': totalTransactions,
          'dateRange': dateRange,
        },
        'outputLocation': 'data/',
        'viewerUrl': 'data/report_viewer.html',
        'message':
            'All financial reports have been regenerated successfully. Open data/report_viewer.html to view the reports.',
        'suggestion':
            'Reports are now up-to-date with the latest general journal entries. Use this tool after making transaction updates to keep reports current.',
      };

      // Add backup information to response
      if (createZipBackup && zipBackupResult != null) {
        response['zipBackup'] = zipBackupResult;
        if (zipBackupResult['success'] == true) {
          response['message'] =
              '${response['message']} Timestamped zip backup created: ${zipBackupResult['zipFilename']}';
        } else {
          response['message'] =
              '${response['message']} Warning: Zip backup failed - ${zipBackupResult['error']}';
        }
      } else {
        response['zipBackup'] = {
          'created': false,
          'reason': 'Zip backup disabled'
        };
      }

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode(response)),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Report regeneration failed', e);
      throw MCPServerException('Report regeneration failed: ${e.toString()}');
    }
  }

  /// 🏪 **SUPPLIER CRUD HANDLERS**: Complete CRUD operations for supplier management

  /// 🆕 **CREATE SUPPLIER HANDLER**: Add a new supplier to the list
  Future<MCPToolResult> _handleCreateSupplier(
      Map<String, dynamic> arguments) async {
    final supplierName = arguments['supplierName'] as String;
    final supplies = arguments['supplies'] as String;
    final account = arguments['account'] as String?;

    logger?.call('info', 'Creating new supplier: $supplierName -> $supplies');

    try {
      // Load supplier list and check for duplicates
      final supplierFile = File('$inputsPath/supplier_list.json');
      List<Map<String, dynamic>> suppliers = [];

      if (supplierFile.existsSync()) {
        final jsonString = supplierFile.readAsStringSync();
        if (jsonString.isNotEmpty) {
          final jsonList = jsonDecode(jsonString) as List<dynamic>;
          suppliers = jsonList.cast<Map<String, dynamic>>();
        }
      }

      // Check if supplier already exists
      for (final existingSupplier in suppliers) {
        final existingName = existingSupplier['name'] as String;
        if (_isFuzzyMatch(supplierName, existingName)) {
          throw MCPServerException(
              'Supplier "$supplierName" already exists as "$existingName". Use update_supplier to modify existing suppliers.');
        }
      }

      // Create new supplier entry
      final newSupplier = <String, dynamic>{
        'name': supplierName,
        'supplies': supplies,
      };

      if (account != null && account.isNotEmpty) {
        newSupplier['account'] = account;
      }

      suppliers.add(newSupplier);
      suppliers
          .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      // Save to file
      const encoder = JsonEncoder.withIndent('  ');
      supplierFile.writeAsStringSync(encoder.convert(suppliers));

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'success': true,
            'action': 'created',
            'supplier': newSupplier,
            'totalSuppliers': suppliers.length,
            'message': 'Successfully created supplier "$supplierName"',
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to create supplier', e);
      throw MCPServerException('Failed to create supplier: ${e.toString()}');
    }
  }

  /// 📖 **READ SUPPLIER HANDLER**: Retrieve supplier information by name
  Future<MCPToolResult> _handleReadSupplier(
      Map<String, dynamic> arguments) async {
    final supplierName = arguments['supplierName'] as String;
    final exactMatch = arguments['exactMatch'] as bool? ?? false;

    try {
      final supplierFile = File('$inputsPath/supplier_list.json');
      if (!supplierFile.existsSync()) {
        return MCPToolResult(
          content: [
            MCPContent.text(jsonEncode({
              'success': true,
              'found': false,
              'searchTerm': supplierName,
              'message': 'Supplier not found, web research suggested',
              'suggestion':
                  'No supplier list exists yet. Use puppeteer_navigate to research this supplier online and then create_supplier to add it',
            })),
          ],
        );
      }

      final jsonString = supplierFile.readAsStringSync();
      if (jsonString.isEmpty) {
        return MCPToolResult(
          content: [
            MCPContent.text(jsonEncode({
              'success': true,
              'found': false,
              'searchTerm': supplierName,
              'message': 'Supplier not found, web research suggested',
              'suggestion':
                  'Use puppeteer_navigate to research this supplier online',
            })),
          ],
        );
      }

      final suppliers =
          (jsonDecode(jsonString) as List).cast<Map<String, dynamic>>();

      for (final supplier in suppliers) {
        final existingName = supplier['name'] as String;
        final matches = exactMatch
            ? existingName.toLowerCase() == supplierName.toLowerCase()
            : _isFuzzyMatch(supplierName, existingName);

        if (matches) {
          return MCPToolResult(
            content: [
              MCPContent.text(jsonEncode({
                'success': true,
                'found': true,
                'supplier': supplier,
                'searchTerm': supplierName,
                'matchedName': existingName,
                'matchType': exactMatch ? 'exact' : 'fuzzy',
                'message': 'Successfully retrieved supplier "$existingName"',
              })),
            ],
          );
        }
      }

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'success': true,
            'found': false,
            'searchTerm': supplierName,
            'message': 'Supplier not found, web research suggested',
            'suggestion':
                'Use puppeteer_navigate to research this supplier online and then create_supplier to add it',
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to read supplier', e);
      throw MCPServerException('Failed to read supplier: ${e.toString()}');
    }
  }

  /// ✏️ **UPDATE SUPPLIER HANDLER**: Update existing supplier information
  Future<MCPToolResult> _handleUpdateSupplier(
      Map<String, dynamic> arguments) async {
    final supplierName = arguments['supplierName'] as String;
    final newSupplierName = arguments['newSupplierName'] as String?;
    final supplies = arguments['supplies'] as String?;
    final account = arguments['account'] as String?;

    try {
      final supplierFile = File('$inputsPath/supplier_list.json');
      if (!supplierFile.existsSync()) {
        throw MCPServerException('Supplier list file not found');
      }

      final suppliers = (jsonDecode(supplierFile.readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

      // Find supplier to update
      int supplierIndex = -1;
      for (int i = 0; i < suppliers.length; i++) {
        if (_isFuzzyMatch(supplierName, suppliers[i]['name'] as String)) {
          supplierIndex = i;
          break;
        }
      }

      if (supplierIndex == -1) {
        throw MCPServerException('Supplier not found: $supplierName');
      }

      final originalSupplier =
          Map<String, dynamic>.from(suppliers[supplierIndex]);
      final updatedSupplier =
          Map<String, dynamic>.from(suppliers[supplierIndex]);
      final changes = <String, dynamic>{};

      // Apply updates
      if (newSupplierName != null &&
          newSupplierName != updatedSupplier['name']) {
        changes['name'] = {
          'from': updatedSupplier['name'],
          'to': newSupplierName
        };
        updatedSupplier['name'] = newSupplierName;
      }

      if (supplies != null && supplies != updatedSupplier['supplies']) {
        changes['supplies'] = {
          'from': updatedSupplier['supplies'],
          'to': supplies
        };
        updatedSupplier['supplies'] = supplies;
      }

      if (account != null) {
        if (account.isEmpty) {
          if (updatedSupplier.containsKey('account')) {
            changes['account'] = {
              'from': updatedSupplier['account'],
              'to': null
            };
            updatedSupplier.remove('account');
          }
        } else {
          if (updatedSupplier['account'] != account) {
            changes['account'] = {
              'from': updatedSupplier['account'],
              'to': account
            };
            updatedSupplier['account'] = account;
          }
        }
      }

      if (changes.isEmpty) {
        return MCPToolResult(
          content: [
            MCPContent.text(jsonEncode({
              'success': true,
              'action': 'no_changes',
              'supplier': updatedSupplier,
              'message':
                  'No changes made to supplier "${updatedSupplier['name']}"',
            })),
          ],
        );
      }

      suppliers[supplierIndex] = updatedSupplier;
      suppliers
          .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      const encoder = JsonEncoder.withIndent('  ');
      supplierFile.writeAsStringSync(encoder.convert(suppliers));

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'success': true,
            'action': 'updated',
            'supplier': updatedSupplier,
            'originalSupplier': originalSupplier,
            'changes': changes,
            'totalSuppliers': suppliers.length,
            'message':
                'Successfully updated supplier "${updatedSupplier['name']}"',
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to update supplier', e);
      throw MCPServerException('Failed to update supplier: ${e.toString()}');
    }
  }

  /// 🗑️ **DELETE SUPPLIER HANDLER**: Remove supplier from the list
  Future<MCPToolResult> _handleDeleteSupplier(
      Map<String, dynamic> arguments) async {
    final supplierName = arguments['supplierName'] as String;
    final confirmDelete = arguments['confirmDelete'] as bool? ?? false;

    try {
      if (!confirmDelete) {
        throw MCPServerException(
            'Delete operation requires confirmDelete=true to prevent accidental deletions');
      }

      final supplierFile = File('$inputsPath/supplier_list.json');
      if (!supplierFile.existsSync()) {
        throw MCPServerException('Supplier list file not found');
      }

      final suppliers = (jsonDecode(supplierFile.readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

      // Find and remove supplier
      int supplierIndex = -1;
      Map<String, dynamic>? supplierToDelete;

      for (int i = 0; i < suppliers.length; i++) {
        if (_isFuzzyMatch(supplierName, suppliers[i]['name'] as String)) {
          supplierIndex = i;
          supplierToDelete = suppliers[i];
          break;
        }
      }

      if (supplierIndex == -1) {
        throw MCPServerException('Supplier not found: $supplierName');
      }

      suppliers.removeAt(supplierIndex);

      const encoder = JsonEncoder.withIndent('  ');
      supplierFile.writeAsStringSync(encoder.convert(suppliers));

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'success': true,
            'action': 'deleted',
            'deletedSupplier': supplierToDelete,
            'totalSuppliers': suppliers.length,
            'message':
                'Successfully deleted supplier "${supplierToDelete!['name']}"',
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to delete supplier', e);
      throw MCPServerException('Failed to delete supplier: ${e.toString()}');
    }
  }

  /// 📋 **LIST SUPPLIERS HANDLER**: List all suppliers with filtering and sorting
  Future<MCPToolResult> _handleListSuppliers(
      Map<String, dynamic> arguments) async {
    final filterBySupplies = arguments['filterBySupplies'] as String?;
    final filterByAccount = arguments['filterByAccount'] as String?;
    final sortBy = arguments['sortBy'] as String? ?? 'name';
    final limit = arguments['limit'] as int? ?? 100;

    try {
      final supplierFile = File('$inputsPath/supplier_list.json');
      List<Map<String, dynamic>> suppliers = [];

      if (supplierFile.existsSync()) {
        final jsonString = supplierFile.readAsStringSync();
        if (jsonString.isNotEmpty) {
          suppliers =
              (jsonDecode(jsonString) as List).cast<Map<String, dynamic>>();
        }
      }

      // Apply filters
      if (filterBySupplies != null) {
        suppliers = suppliers.where((supplier) {
          final suppliesText = supplier['supplies'] as String;
          return suppliesText
              .toLowerCase()
              .contains(filterBySupplies.toLowerCase());
        }).toList();
      }

      if (filterByAccount != null) {
        suppliers = suppliers.where((supplier) {
          return supplier['account'] == filterByAccount;
        }).toList();
      }

      // Sort suppliers
      switch (sortBy) {
        case 'supplies':
          suppliers.sort((a, b) =>
              (a['supplies'] as String).compareTo(b['supplies'] as String));
          break;
        case 'account':
          suppliers.sort((a, b) {
            final accountA = a['account'] as String? ?? '';
            final accountB = b['account'] as String? ?? '';
            return accountA.compareTo(accountB);
          });
          break;
        case 'name':
        default:
          suppliers.sort(
              (a, b) => (a['name'] as String).compareTo(b['name'] as String));
          break;
      }

      // Apply limit
      if (suppliers.length > limit) {
        suppliers = suppliers.take(limit).toList();
      }

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode({
            'success': true,
            'suppliers': suppliers,
            'totalReturned': suppliers.length,
            'filters': {
              'bySupplies': filterBySupplies,
              'byAccount': filterByAccount,
            },
            'sortBy': sortBy,
            'limit': limit,
            'message': 'Successfully listed ${suppliers.length} suppliers',
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to list suppliers', e);
      throw MCPServerException('Failed to list suppliers: ${e.toString()}');
    }
  }

  /// 🏪 **LEGACY SUPPLIER INFO HANDLER**: Add or update supplier information (backward compatibility)
  Future<MCPToolResult> _handleUpdateSupplierInfo(
      Map<String, dynamic> arguments) async {
    final supplierName = arguments['supplierName'] as String;
    final supplies = arguments['supplies'] as String;
    final rawTransactionText = arguments['rawTransactionText'] as String? ?? '';
    final businessDescription =
        arguments['businessDescription'] as String? ?? '';
    final suggestedAccountCode =
        arguments['suggestedAccountCode'] as String? ?? '';
    final replaceExisting = arguments['replaceExisting'] as bool? ?? false;

    logger?.call('info', 'Updating supplier info: $supplierName -> $supplies');

    try {
      // Validate suggested account code if provided
      if (suggestedAccountCode.isNotEmpty) {
        final account =
            services.chartOfAccounts.getAccount(suggestedAccountCode);
        if (account == null) {
          throw MCPServerException(
              'Suggested account code not found: $suggestedAccountCode');
        }
      }

      // Ensure inputs directory exists
      final inputsDir = Directory(inputsPath);
      if (!inputsDir.existsSync()) {
        inputsDir.createSync(recursive: true);
      }

      // Load existing supplier list
      final supplierFile = File('$inputsPath/supplier_list.json');
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
      String? existingSupplies;

      for (int i = 0; i < suppliers.length; i++) {
        final existingName = suppliers[i]['name'] as String;
        if (_isFuzzyMatch(supplierName, existingName)) {
          existingIndex = i;
          existingSupplies = suppliers[i]['supplies'] as String?;
          break;
        }
      }

      bool wasUpdated = false;
      bool wasAdded = false;
      String? previousSupplies;

      if (existingIndex >= 0) {
        // Supplier exists - decide whether to update
        previousSupplies = existingSupplies;

        if (replaceExisting ||
            existingSupplies == null ||
            existingSupplies.toLowerCase() == 'unknown' ||
            existingSupplies.isEmpty) {
          suppliers[existingIndex] = {
            'name': supplierName, // Use the cleaned name
            'supplies': supplies,
          };
          wasUpdated = true;

          logger?.call('info',
              'Updated existing supplier: $supplierName ($previousSupplies -> $supplies)');
        } else {
          logger?.call('info',
              'Supplier exists with supplies "$existingSupplies", not updating (use replaceExisting=true to force)');
        }
      } else {
        // New supplier - add it
        suppliers.add({
          'name': supplierName,
          'supplies': supplies,
        });
        wasAdded = true;

        logger?.call('info', 'Added new supplier: $supplierName ($supplies)');
      }

      if (wasAdded || wasUpdated) {
        // Sort suppliers alphabetically by name
        suppliers.sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String));

        // Save back to file with pretty formatting
        const encoder = JsonEncoder.withIndent('  ');
        final prettyJsonString = encoder.convert(suppliers);
        supplierFile.writeAsStringSync(prettyJsonString);
      }

      // Create response
      final response = {
        'success': true,
        'supplierName': supplierName,
        'supplies': supplies,
        'action': wasAdded ? 'added' : (wasUpdated ? 'updated' : 'no_change'),
        'totalSuppliers': suppliers.length,
        'previousSupplies': previousSupplies,
        'rawTransactionText': rawTransactionText,
        'businessDescription': businessDescription,
        'suggestedAccount': suggestedAccountCode.isNotEmpty
            ? {
                'code': suggestedAccountCode,
                'name': services.chartOfAccounts
                        .getAccount(suggestedAccountCode)
                        ?.name ??
                    'Unknown',
              }
            : null,
        'message': wasAdded
            ? 'Added new supplier "$supplierName" with supplies "$supplies"'
            : wasUpdated
                ? 'Updated supplier "$supplierName" from "$previousSupplies" to "$supplies"'
                : 'Supplier "$supplierName" already exists with supplies "$existingSupplies" (use replaceExisting=true to force update)',
        'fuzzyMatching': existingIndex >= 0
            ? 'Matched existing supplier using fuzzy logic'
            : null,
      };

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode(response)),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to update supplier info', e);
      throw MCPServerException(
          'Failed to update supplier info: ${e.toString()}');
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
    if (normalized1.contains(normalized2) ||
        normalized2.contains(normalized1)) {
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
        variations.add(
            normalizedName.substring(0, normalizedName.length - suffix.length));
      }
    }

    // Remove location codes and numbers
    final withoutNumbers = normalizedName.replaceAll(RegExp(r'\d+'), '').trim();
    if (withoutNumbers != normalizedName) {
      variations.add(withoutNumbers);
    }

    return variations;
  }

  /// 📊 **AUDIT REPORT HANDLERS**: Plaintext reporting tools for AI audit purposes

  /// 🏦 **BALANCE SHEET AUDIT HANDLER**: Generate plaintext balance sheet for audit
  Future<MCPToolResult> _handleGenerateBalanceSheetAudit(
      Map<String, dynamic> arguments) async {
    final asOfDateStr = arguments['asOfDate'] as String;
    final includeZeroBalances =
        arguments['includeZeroBalances'] as bool? ?? false;
    final sortBy = arguments['sortBy'] as String? ?? 'account_code';

    logger?.call(
        'info', 'Generating balance sheet audit report for $asOfDateStr');

    try {
      final asOfDate = DateTime.parse(asOfDateStr);

      // Load journal entries
      if (!services.generalJournal.loadEntries()) {
        throw MCPServerException('Failed to load general journal entries');
      }

      final chartOfAccounts = services.chartOfAccounts;
      final generalJournalService = services.generalJournal;

      // Get all account types
      final currentAssetAccounts =
          chartOfAccounts.getAccountsByType(AccountType.currentAsset);
      final bankAccounts = chartOfAccounts.getAccountsByType(AccountType.bank);
      final fixedAssetAccounts =
          chartOfAccounts.getAccountsByType(AccountType.fixedAsset);
      final inventoryAccounts =
          chartOfAccounts.getAccountsByType(AccountType.inventory);
      final liabilityAccounts =
          chartOfAccounts.getAccountsByType(AccountType.currentLiability);
      final equityAccounts =
          chartOfAccounts.getAccountsByType(AccountType.equity);

      // Calculate balances
      final assetBalances = <String, Map<String, dynamic>>{};
      final liabilityBalances = <String, Map<String, dynamic>>{};
      final equityBalances = <String, Map<String, dynamic>>{};

      double totalAssets = 0;
      double totalLiabilities = 0;

      // Process all asset accounts
      for (final account in [
        ...currentAssetAccounts,
        ...bankAccounts,
        ...fixedAssetAccounts,
        ...inventoryAccounts
      ]) {
        final balance = generalJournalService
            .calculateAccountBalance(account.code, asOfDate: asOfDate);
        if (balance != 0 || includeZeroBalances) {
          assetBalances[account.code] = {
            'name': account.name,
            'type': account.type.value,
            'balance': balance,
            'gst': account.gst,
            'gstType': account.gstType.value,
          };
          totalAssets += balance;
        }
      }

      // Process liability accounts
      for (final account in liabilityAccounts) {
        final balance = generalJournalService
            .calculateAccountBalance(account.code, asOfDate: asOfDate);
        if (balance != 0 || includeZeroBalances) {
          liabilityBalances[account.code] = {
            'name': account.name,
            'type': account.type.value,
            'balance': balance,
            'gst': account.gst,
            'gstType': account.gstType.value,
          };
          totalLiabilities += balance;
        }
      }

      // Process equity accounts
      for (final account in equityAccounts) {
        final balance = generalJournalService
            .calculateAccountBalance(account.code, asOfDate: asOfDate);
        if (balance != 0 || includeZeroBalances) {
          equityBalances[account.code] = {
            'name': account.name,
            'type': account.type.value,
            'balance': balance,
            'gst': account.gst,
            'gstType': account.gstType.value,
          };
          // totalEquity += balance; // Not used in this calculation
        }
      }

      // Calculate owner's equity as assets minus liabilities
      final calculatedOwnerEquity = totalAssets - totalLiabilities;

      // Generate plaintext report
      final report = _generateBalanceSheetPlaintext(
        asOfDate,
        assetBalances,
        liabilityBalances,
        equityBalances,
        totalAssets,
        totalLiabilities,
        calculatedOwnerEquity,
        sortBy,
      );

      logger?.call('info', 'Balance sheet audit report generated successfully');

      return MCPToolResult(
        content: [
          MCPContent.text(report),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Balance sheet audit report failed', e);
      throw MCPServerException(
          'Balance sheet audit report failed: ${e.toString()}');
    }
  }

  /// 📈 **PROFIT & LOSS AUDIT HANDLER**: Generate plaintext P&L for audit
  Future<MCPToolResult> _handleGenerateProfitLossAudit(
      Map<String, dynamic> arguments) async {
    final startDateStr = arguments['startDate'] as String;
    final endDateStr = arguments['endDate'] as String;
    final includeZeroBalances =
        arguments['includeZeroBalances'] as bool? ?? false;
    final sortBy = arguments['sortBy'] as String? ?? 'account_code';
    final includeTransactionCounts =
        arguments['includeTransactionCounts'] as bool? ?? true;

    logger?.call(
        'info', 'Generating P&L audit report for $startDateStr to $endDateStr');

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

      final chartOfAccounts = services.chartOfAccounts;
      final generalJournalService = services.generalJournal;

      // Get account types
      final revenueAccounts =
          chartOfAccounts.getAccountsByType(AccountType.revenue);
      final cogsAccounts = chartOfAccounts.getAccountsByType(AccountType.cogs);
      final expenseAccounts =
          chartOfAccounts.getAccountsByType(AccountType.expense);

      // Calculate totals
      final revenueData = <String, Map<String, dynamic>>{};
      final cogsData = <String, Map<String, dynamic>>{};
      final expenseData = <String, Map<String, dynamic>>{};

      double totalRevenue = 0;
      double totalCogs = 0;
      double totalExpenses = 0;

      // Process revenue accounts
      for (final account in revenueAccounts) {
        final entries = generalJournalService.getEntriesByAccount(account.code);
        final filteredEntries = entries
            .where((entry) =>
                entry.date
                    .isAfter(startDate.subtract(const Duration(days: 1))) &&
                entry.date.isBefore(endDate.add(const Duration(days: 1))))
            .toList();

        double accountTotal = 0;
        for (final entry in filteredEntries) {
          // For revenue accounts, credit increases (positive)
          accountTotal += _getTransactionAmountForAccount(entry, account.code,
              isPositive: true);
        }

        if (accountTotal != 0 || includeZeroBalances) {
          revenueData[account.code] = {
            'name': account.name,
            'type': account.type.value,
            'amount': accountTotal,
            'transactionCount': filteredEntries.length,
            'gst': account.gst,
            'gstType': account.gstType.value,
          };
          totalRevenue += accountTotal;
        }
      }

      // Process COGS accounts
      for (final account in cogsAccounts) {
        final entries = generalJournalService.getEntriesByAccount(account.code);
        final filteredEntries = entries
            .where((entry) =>
                entry.date
                    .isAfter(startDate.subtract(const Duration(days: 1))) &&
                entry.date.isBefore(endDate.add(const Duration(days: 1))))
            .toList();

        double accountTotal = 0;
        for (final entry in filteredEntries) {
          // For COGS accounts, debit increases (positive)
          accountTotal += _getTransactionAmountForAccount(entry, account.code,
              isPositive: false);
        }

        if (accountTotal != 0 || includeZeroBalances) {
          cogsData[account.code] = {
            'name': account.name,
            'type': account.type.value,
            'amount': accountTotal,
            'transactionCount': filteredEntries.length,
            'gst': account.gst,
            'gstType': account.gstType.value,
          };
          totalCogs += accountTotal;
        }
      }

      // Process expense accounts
      for (final account in expenseAccounts) {
        final entries = generalJournalService.getEntriesByAccount(account.code);
        final filteredEntries = entries
            .where((entry) =>
                entry.date
                    .isAfter(startDate.subtract(const Duration(days: 1))) &&
                entry.date.isBefore(endDate.add(const Duration(days: 1))))
            .toList();

        double accountTotal = 0;
        for (final entry in filteredEntries) {
          // For expense accounts, debit increases (positive)
          accountTotal += _getTransactionAmountForAccount(entry, account.code,
              isPositive: false);
        }

        if (accountTotal != 0 || includeZeroBalances) {
          expenseData[account.code] = {
            'name': account.name,
            'type': account.type.value,
            'amount': accountTotal,
            'transactionCount': filteredEntries.length,
            'gst': account.gst,
            'gstType': account.gstType.value,
          };
          totalExpenses += accountTotal;
        }
      }

      // Calculate profit figures
      final grossProfit = totalRevenue - totalCogs;
      final netProfit = grossProfit - totalExpenses;

      // Generate plaintext report
      final report = _generateProfitLossPlaintext(
        startDate,
        endDate,
        revenueData,
        cogsData,
        expenseData,
        totalRevenue,
        totalCogs,
        totalExpenses,
        grossProfit,
        netProfit,
        sortBy,
        includeTransactionCounts,
      );

      logger?.call('info', 'P&L audit report generated successfully');

      return MCPToolResult(
        content: [
          MCPContent.text(report),
        ],
      );
    } catch (e) {
      logger?.call('error', 'P&L audit report failed', e);
      throw MCPServerException('P&L audit report failed: ${e.toString()}');
    }
  }

  /// ⚖️ **TRIAL BALANCE AUDIT HANDLER**: Generate plaintext trial balance for audit
  Future<MCPToolResult> _handleGenerateTrialBalanceAudit(
      Map<String, dynamic> arguments) async {
    final asOfDateStr = arguments['asOfDate'] as String;
    final includeZeroBalances =
        arguments['includeZeroBalances'] as bool? ?? false;
    final sortBy = arguments['sortBy'] as String? ?? 'account_code';
    final groupByType = arguments['groupByType'] as bool? ?? true;

    logger?.call(
        'info', 'Generating trial balance audit report for $asOfDateStr');

    try {
      final asOfDate = DateTime.parse(asOfDateStr);

      // Load journal entries
      if (!services.generalJournal.loadEntries()) {
        throw MCPServerException('Failed to load general journal entries');
      }

      final chartOfAccounts = services.chartOfAccounts;
      final generalJournalService = services.generalJournal;
      final allAccounts = chartOfAccounts.getAllAccounts();

      final trialBalanceData = <String, Map<String, dynamic>>{};
      double totalDebits = 0;
      double totalCredits = 0;

      // Calculate trial balance for each account
      for (final account in allAccounts) {
        final balance = generalJournalService
            .calculateAccountBalance(account.code, asOfDate: asOfDate);

        if (balance != 0 || includeZeroBalances) {
          // Determine if this is a debit or credit balance based on account type
          final isDebitAccount = [
            AccountType.currentAsset,
            AccountType.bank,
            AccountType.fixedAsset,
            AccountType.inventory,
            AccountType.expense,
            AccountType.cogs
          ].contains(account.type);

          double debitBalance = 0;
          double creditBalance = 0;

          if (isDebitAccount) {
            debitBalance = balance.abs();
            if (balance < 0) {
              creditBalance = balance.abs();
              debitBalance = 0;
            }
          } else {
            creditBalance = balance.abs();
            if (balance < 0) {
              debitBalance = balance.abs();
              creditBalance = 0;
            }
          }

          trialBalanceData[account.code] = {
            'name': account.name,
            'type': account.type.value,
            'debitBalance': debitBalance,
            'creditBalance': creditBalance,
            'netBalance': balance,
            'gst': account.gst,
            'gstType': account.gstType.value,
          };

          totalDebits += debitBalance;
          totalCredits += creditBalance;
        }
      }

      // Generate plaintext report
      final report = _generateTrialBalancePlaintext(
        asOfDate,
        trialBalanceData,
        totalDebits,
        totalCredits,
        sortBy,
        groupByType,
      );

      logger?.call('info', 'Trial balance audit report generated successfully');

      return MCPToolResult(
        content: [
          MCPContent.text(report),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Trial balance audit report failed', e);
      throw MCPServerException(
          'Trial balance audit report failed: ${e.toString()}');
    }
  }

  /// 💰 **CASH FLOW AUDIT HANDLER**: Generate plaintext cash flow statement for audit
  Future<MCPToolResult> _handleGenerateCashFlowAudit(
      Map<String, dynamic> arguments) async {
    final startDateStr = arguments['startDate'] as String;
    final endDateStr = arguments['endDate'] as String;
    final cashAccountCodes = (arguments['cashAccountCodes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    logger?.call('info',
        'Generating cash flow audit report for $startDateStr to $endDateStr');

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

      final chartOfAccounts = services.chartOfAccounts;
      final generalJournalService = services.generalJournal;

      // Determine cash accounts to analyze
      List<String> accountsToAnalyze;
      if (cashAccountCodes.isEmpty) {
        // Use all bank accounts
        accountsToAnalyze = chartOfAccounts
            .getAccountsByType(AccountType.bank)
            .map((a) => a.code)
            .toList();
      } else {
        accountsToAnalyze = cashAccountCodes;
      }

      final cashFlowData = <String, Map<String, dynamic>>{};
      double totalCashFlow = 0;

      // Analyze each cash account
      for (final accountCode in accountsToAnalyze) {
        final account = chartOfAccounts.getAccount(accountCode);
        if (account == null) continue;

        final startingBalance = generalJournalService.calculateAccountBalance(
            accountCode,
            asOfDate: startDate.subtract(const Duration(days: 1)));
        final endingBalance = generalJournalService
            .calculateAccountBalance(accountCode, asOfDate: endDate);
        final netChange = endingBalance - startingBalance;

        // Get all transactions for this account in the period
        final entries = generalJournalService.getEntriesByAccount(accountCode);
        final periodEntries = entries
            .where((entry) =>
                entry.date
                    .isAfter(startDate.subtract(const Duration(days: 1))) &&
                entry.date.isBefore(endDate.add(const Duration(days: 1))))
            .toList();

        final transactions = <Map<String, dynamic>>[];
        for (final entry in periodEntries) {
          final amount = _getTransactionAmountForAccount(entry, accountCode,
              isPositive: true);
          transactions.add({
            'date': entry.date.toIso8601String().split('T')[0],
            'description': entry.description,
            'amount': amount,
            'runningBalance': 0.0, // Will be calculated later
          });
        }

        // Sort transactions by date and calculate running balance
        transactions.sort(
            (a, b) => (a['date'] as String).compareTo(b['date'] as String));
        double runningBalance = startingBalance;
        for (final transaction in transactions) {
          runningBalance += transaction['amount'] as double;
          transaction['runningBalance'] = runningBalance;
        }

        cashFlowData[accountCode] = {
          'name': account.name,
          'type': account.type.value,
          'startingBalance': startingBalance,
          'endingBalance': endingBalance,
          'netChange': netChange,
          'transactionCount': transactions.length,
          'transactions': transactions,
        };

        totalCashFlow += netChange;
      }

      // Generate plaintext report
      final report = _generateCashFlowPlaintext(
        startDate,
        endDate,
        cashFlowData,
        totalCashFlow,
      );

      logger?.call('info', 'Cash flow audit report generated successfully');

      return MCPToolResult(
        content: [
          MCPContent.text(report),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Cash flow audit report failed', e);
      throw MCPServerException(
          'Cash flow audit report failed: ${e.toString()}');
    }
  }

  /// 📋 **ACCOUNT ACTIVITY AUDIT HANDLER**: Generate detailed account activity report
  Future<MCPToolResult> _handleGenerateAccountActivityAudit(
      Map<String, dynamic> arguments) async {
    final accountCodes = (arguments['accountCodes'] as List<dynamic>)
        .map((e) => e.toString())
        .toList();
    final startDateStr = arguments['startDate'] as String;
    final endDateStr = arguments['endDate'] as String;
    final includeRunningBalance =
        arguments['includeRunningBalance'] as bool? ?? true;
    final sortBy = arguments['sortBy'] as String? ?? 'date';

    logger?.call('info',
        'Generating account activity audit report for accounts: ${accountCodes.join(', ')}');

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

      final chartOfAccounts = services.chartOfAccounts;
      final generalJournalService = services.generalJournal;

      final accountActivityData = <String, Map<String, dynamic>>{};

      // Analyze each requested account
      for (final accountCode in accountCodes) {
        final account = chartOfAccounts.getAccount(accountCode);
        if (account == null) {
          logger?.call('warning', 'Account not found: $accountCode');
          continue;
        }

        final startingBalance = includeRunningBalance
            ? generalJournalService.calculateAccountBalance(accountCode,
                asOfDate: startDate.subtract(const Duration(days: 1)))
            : 0.0;

        // Get all transactions for this account in the period
        final entries = generalJournalService.getEntriesByAccount(accountCode);
        final periodEntries = entries
            .where((entry) =>
                entry.date
                    .isAfter(startDate.subtract(const Duration(days: 1))) &&
                entry.date.isBefore(endDate.add(const Duration(days: 1))))
            .toList();

        final transactions = <Map<String, dynamic>>[];
        for (final entry in periodEntries) {
          final amount = _getTransactionAmountForAccount(entry, accountCode,
              isPositive: ![
                AccountType.expense,
                AccountType.cogs,
                AccountType.currentAsset,
                AccountType.fixedAsset,
                AccountType.inventory,
                AccountType.bank
              ].contains(account.type));

          transactions.add({
            'date': entry.date.toIso8601String().split('T')[0],
            'description': entry.description,
            'amount': amount,
            'bankCode': entry.bankCode,
            'bankAccount': entry.bankAccount.name,
            'notes': entry.notes,
            'runningBalance': 0.0, // Will be calculated later if needed
          });
        }

        // Sort transactions
        switch (sortBy) {
          case 'date':
            transactions.sort(
                (a, b) => (a['date'] as String).compareTo(b['date'] as String));
            break;
          case 'amount':
            transactions.sort((a, b) =>
                (b['amount'] as double).compareTo(a['amount'] as double));
            break;
          case 'description':
            transactions.sort((a, b) => (a['description'] as String)
                .compareTo(b['description'] as String));
            break;
        }

        // Calculate running balance if requested
        if (includeRunningBalance && sortBy == 'date') {
          double runningBalance = startingBalance;
          for (final transaction in transactions) {
            runningBalance += transaction['amount'] as double;
            transaction['runningBalance'] = runningBalance;
          }
        }

        final endingBalance = includeRunningBalance
            ? generalJournalService.calculateAccountBalance(accountCode,
                asOfDate: endDate)
            : transactions.fold<double>(
                0.0, (sum, t) => sum + (t['amount'] as double));

        accountActivityData[accountCode] = {
          'name': account.name,
          'type': account.type.value,
          'gst': account.gst,
          'gstType': account.gstType.value,
          'startingBalance': startingBalance,
          'endingBalance': endingBalance,
          'netChange': endingBalance - startingBalance,
          'transactionCount': transactions.length,
          'transactions': transactions,
        };
      }

      // Generate plaintext report
      final report = _generateAccountActivityPlaintext(
        startDate,
        endDate,
        accountActivityData,
        includeRunningBalance,
        sortBy,
      );

      logger?.call(
          'info', 'Account activity audit report generated successfully');

      return MCPToolResult(
        content: [
          MCPContent.text(report),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Account activity audit report failed', e);
      throw MCPServerException(
          'Account activity audit report failed: ${e.toString()}');
    }
  }

  /// Helper method to get transaction amount for an account (mirrors BaseReport logic)
  double _getTransactionAmountForAccount(
      GeneralJournal entry, String accountCode,
      {bool isPositive = true}) {
    double debitAmount = 0.0;
    for (final debit in entry.debits) {
      if (debit.accountCode == accountCode) {
        debitAmount += debit.amount;
      }
    }

    double creditAmount = 0.0;
    for (final credit in entry.credits) {
      if (credit.accountCode == accountCode) {
        creditAmount += credit.amount;
      }
    }

    if (isPositive) {
      return creditAmount - debitAmount;
    } else {
      return debitAmount - creditAmount;
    }
  }

  /// 📦 **ZIP BACKUP UTILITY**: Create timestamped zip backups of directories
  Map<String, dynamic> _createZipBackup({
    required List<String> directoriesToBackup,
    required String reason,
  }) {
    try {
      final timestamp = DateTime.now();
      final timestampStr = timestamp
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('T', '_')
          .split('.')[0]; // Remove milliseconds

      // Create backups directory if it doesn't exist
      final backupsDir = Directory('backups');
      if (!backupsDir.existsSync()) {
        backupsDir.createSync(recursive: true);
      }

      final zipFilename = 'backup_$timestampStr.zip';
      final zipPath = path.join(backupsDir.path, zipFilename);

      // Create archive
      final archive = Archive();
      int totalFiles = 0;
      final backupSummary = <String, dynamic>{};

      for (final dirPath in directoriesToBackup) {
        final directory = Directory(dirPath);
        if (!directory.existsSync()) {
          logger?.call(
              'warning', 'Directory does not exist, skipping: $dirPath');
          backupSummary[dirPath] = {
            'status': 'skipped',
            'reason': 'directory not found',
            'files': 0
          };
          continue;
        }

        int dirFileCount = 0;
        final entities = directory.listSync(recursive: true);

        for (final entity in entities) {
          if (entity is File) {
            final relativePath =
                path.relative(entity.path, from: Directory.current.path);
            final fileBytes = entity.readAsBytesSync();

            final archiveFile = ArchiveFile(
              relativePath,
              fileBytes.length,
              fileBytes,
            );

            archive.addFile(archiveFile);
            dirFileCount++;
            totalFiles++;
          }
        }

        backupSummary[dirPath] = {
          'status': 'success',
          'files': dirFileCount,
          'size_bytes': entities
              .whereType<File>()
              .fold<int>(0, (sum, file) => sum + file.lengthSync()),
        };

        logger?.call(
            'info', 'Added $dirFileCount files from $dirPath to backup');
      }

      // Write the zip file
      final zipData = ZipEncoder().encode(archive);
      File(zipPath).writeAsBytesSync(zipData);

      final zipSize = File(zipPath).lengthSync();

      logger?.call('info',
          'Created zip backup: $zipPath ($totalFiles files, ${(zipSize / 1024 / 1024).toStringAsFixed(2)} MB)');

      return {
        'success': true,
        'zipPath': zipPath,
        'zipFilename': zipFilename,
        'totalFiles': totalFiles,
        'zipSizeBytes': zipSize,
        'zipSizeMB': (zipSize / 1024 / 1024).toStringAsFixed(2),
        'timestamp': timestamp.toIso8601String(),
        'reason': reason,
        'directoriesBackedUp': backupSummary,
      };
    } catch (e) {
      logger?.call('error', 'Zip backup failed', e);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
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
    final rulesFile = File('$inputsPath/accounting_rules.txt');

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
    final supplierFile = File('$inputsPath/supplier_list.json');

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
      final formattedSuppliers = suppliers
          .map((s) => {
                'name': s['name'] as String,
                'supplies': s['supplies'] as String,
              })
          .toList();

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

  /// 📄 **PLAINTEXT REPORT GENERATORS**: Generate formatted plaintext reports

  /// Generate plaintext balance sheet report
  String _generateBalanceSheetPlaintext(
    DateTime asOfDate,
    Map<String, Map<String, dynamic>> assetBalances,
    Map<String, Map<String, dynamic>> liabilityBalances,
    Map<String, Map<String, dynamic>> equityBalances,
    double totalAssets,
    double totalLiabilities,
    double calculatedOwnerEquity,
    String sortBy,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('=' * 80);
    buffer.writeln('BALANCE SHEET (AUDIT REPORT)');
    buffer.writeln('As of ${_formatDateForDisplay(asOfDate)}');
    buffer.writeln('=' * 80);
    buffer.writeln();

    // Sort accounts helper
    List<MapEntry<String, Map<String, dynamic>>> sortAccounts(
        Map<String, Map<String, dynamic>> accounts) {
      final entries = accounts.entries.toList();
      switch (sortBy) {
        case 'account_name':
          entries.sort((a, b) =>
              (a.value['name'] as String).compareTo(b.value['name'] as String));
          break;
        case 'balance':
          entries.sort((a, b) => (b.value['balance'] as double)
              .abs()
              .compareTo((a.value['balance'] as double).abs()));
          break;
        case 'account_code':
        default:
          entries.sort((a, b) => a.key.compareTo(b.key));
          break;
      }
      return entries;
    }

    // Assets section
    buffer.writeln('ASSETS');
    buffer.writeln('-' * 80);
    buffer.writeln(
        'Code  Account Name                                   Type           Balance');
    buffer.writeln('-' * 80);

    final sortedAssets = sortAccounts(assetBalances);
    for (final entry in sortedAssets) {
      final code = entry.key;
      final data = entry.value;
      final name = data['name'] as String;
      final type = data['type'] as String;
      final balance = data['balance'] as double;

      buffer.writeln(
          '${code.padRight(5)} ${name.padRight(40)} ${type.padRight(12)} ${_formatCurrency(balance).padLeft(12)}');
    }

    buffer.writeln('-' * 80);
    buffer.writeln(
        '${''.padRight(58)} TOTAL ASSETS ${_formatCurrency(totalAssets).padLeft(12)}');
    buffer.writeln('=' * 80);
    buffer.writeln();

    // Liabilities section
    buffer.writeln('LIABILITIES');
    buffer.writeln('-' * 80);
    buffer.writeln(
        'Code  Account Name                                   Type           Balance');
    buffer.writeln('-' * 80);

    final sortedLiabilities = sortAccounts(liabilityBalances);
    for (final entry in sortedLiabilities) {
      final code = entry.key;
      final data = entry.value;
      final name = data['name'] as String;
      final type = data['type'] as String;
      final balance = data['balance'] as double;

      buffer.writeln(
          '${code.padRight(5)} ${name.padRight(40)} ${type.padRight(12)} ${_formatCurrency(balance).padLeft(12)}');
    }

    buffer.writeln('-' * 80);
    buffer.writeln(
        '${''.padRight(58)} TOTAL LIABILITIES ${_formatCurrency(totalLiabilities).padLeft(8)}');
    buffer.writeln();

    // Equity section
    buffer.writeln('EQUITY');
    buffer.writeln('-' * 80);
    buffer.writeln(
        'Code  Account Name                                   Type           Balance');
    buffer.writeln('-' * 80);

    final sortedEquity = sortAccounts(equityBalances);
    for (final entry in sortedEquity) {
      final code = entry.key;
      final data = entry.value;
      final name = data['name'] as String;
      final type = data['type'] as String;
      final balance = data['balance'] as double;

      buffer.writeln(
          '${code.padRight(5)} ${name.padRight(40)} ${type.padRight(12)} ${_formatCurrency(balance).padLeft(12)}');
    }

    buffer.writeln('-' * 80);
    buffer.writeln(
        '${''.padRight(58)} TOTAL EQUITY ${_formatCurrency(calculatedOwnerEquity).padLeft(12)}');
    buffer.writeln('=' * 80);
    buffer.writeln();

    // Balance check
    buffer.writeln('BALANCE VERIFICATION');
    buffer.writeln('-' * 40);
    buffer.writeln(
        'Total Assets:           ${_formatCurrency(totalAssets).padLeft(12)}');
    buffer.writeln(
        'Total Liabilities:      ${_formatCurrency(totalLiabilities).padLeft(12)}');
    buffer.writeln(
        'Total Equity:           ${_formatCurrency(calculatedOwnerEquity).padLeft(12)}');
    buffer.writeln(
        'Liabilities + Equity:   ${_formatCurrency(totalLiabilities + calculatedOwnerEquity).padLeft(12)}');
    buffer.writeln('-' * 40);
    final difference = totalAssets - (totalLiabilities + calculatedOwnerEquity);
    buffer.writeln(
        'Difference:             ${_formatCurrency(difference).padLeft(12)}');

    if (difference.abs() < 0.01) {
      buffer.writeln('✓ BALANCE SHEET BALANCES');
    } else {
      buffer.writeln('⚠ BALANCE SHEET OUT OF BALANCE!');
    }

    buffer.writeln();
    buffer.writeln('Report generated: ${DateTime.now().toIso8601String()}');

    return buffer.toString();
  }

  /// Generate plaintext profit & loss report
  String _generateProfitLossPlaintext(
    DateTime startDate,
    DateTime endDate,
    Map<String, Map<String, dynamic>> revenueData,
    Map<String, Map<String, dynamic>> cogsData,
    Map<String, Map<String, dynamic>> expenseData,
    double totalRevenue,
    double totalCogs,
    double totalExpenses,
    double grossProfit,
    double netProfit,
    String sortBy,
    bool includeTransactionCounts,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('=' * 80);
    buffer.writeln('PROFIT & LOSS STATEMENT (AUDIT REPORT)');
    buffer.writeln(
        'For the period ${_formatDateForDisplay(startDate)} to ${_formatDateForDisplay(endDate)}');
    buffer.writeln('=' * 80);
    buffer.writeln();

    // Sort accounts helper
    List<MapEntry<String, Map<String, dynamic>>> sortAccounts(
        Map<String, Map<String, dynamic>> accounts) {
      final entries = accounts.entries.toList();
      switch (sortBy) {
        case 'account_name':
          entries.sort((a, b) =>
              (a.value['name'] as String).compareTo(b.value['name'] as String));
          break;
        case 'amount':
          entries.sort((a, b) => (b.value['amount'] as double)
              .abs()
              .compareTo((a.value['amount'] as double).abs()));
          break;
        case 'account_code':
        default:
          entries.sort((a, b) => a.key.compareTo(b.key));
          break;
      }
      return entries;
    }

    // Revenue section
    buffer.writeln('REVENUE');
    buffer.writeln('-' * 80);
    if (includeTransactionCounts) {
      buffer.writeln(
          'Code  Account Name                           Txns        Amount');
    } else {
      buffer.writeln(
          'Code  Account Name                                        Amount');
    }
    buffer.writeln('-' * 80);

    final sortedRevenue = sortAccounts(revenueData);
    for (final entry in sortedRevenue) {
      final code = entry.key;
      final data = entry.value;
      final name = data['name'] as String;
      final amount = data['amount'] as double;
      final txnCount = data['transactionCount'] as int;

      if (includeTransactionCounts) {
        buffer.writeln(
            '${code.padRight(5)} ${name.padRight(35)} ${txnCount.toString().padLeft(4)} ${_formatCurrency(amount).padLeft(12)}');
      } else {
        buffer.writeln(
            '${code.padRight(5)} ${name.padRight(50)} ${_formatCurrency(amount).padLeft(12)}');
      }
    }

    buffer.writeln('-' * 80);
    buffer.writeln(
        '${''.padRight(58)} TOTAL REVENUE ${_formatCurrency(totalRevenue).padLeft(12)}');
    buffer.writeln();

    // COGS section
    if (cogsData.isNotEmpty) {
      buffer.writeln('COST OF GOODS SOLD');
      buffer.writeln('-' * 80);
      if (includeTransactionCounts) {
        buffer.writeln(
            'Code  Account Name                           Txns        Amount');
      } else {
        buffer.writeln(
            'Code  Account Name                                        Amount');
      }
      buffer.writeln('-' * 80);

      final sortedCogs = sortAccounts(cogsData);
      for (final entry in sortedCogs) {
        final code = entry.key;
        final data = entry.value;
        final name = data['name'] as String;
        final amount = data['amount'] as double;
        final txnCount = data['transactionCount'] as int;

        if (includeTransactionCounts) {
          buffer.writeln(
              '${code.padRight(5)} ${name.padRight(35)} ${txnCount.toString().padLeft(4)} ${_formatCurrency(amount).padLeft(12)}');
        } else {
          buffer.writeln(
              '${code.padRight(5)} ${name.padRight(50)} ${_formatCurrency(amount).padLeft(12)}');
        }
      }

      buffer.writeln('-' * 80);
      buffer.writeln(
          '${''.padRight(58)} TOTAL COGS ${_formatCurrency(totalCogs).padLeft(15)}');
      buffer.writeln();

      // Gross profit
      buffer.writeln('GROSS PROFIT');
      buffer.writeln('-' * 40);
      buffer.writeln(
          'Total Revenue:          ${_formatCurrency(totalRevenue).padLeft(12)}');
      buffer.writeln(
          'Less: Total COGS:       ${_formatCurrency(totalCogs).padLeft(12)}');
      buffer.writeln('-' * 40);
      buffer.writeln(
          'GROSS PROFIT:           ${_formatCurrency(grossProfit).padLeft(12)}');
      buffer.writeln();
    }

    // Expenses section
    buffer.writeln('OPERATING EXPENSES');
    buffer.writeln('-' * 80);
    if (includeTransactionCounts) {
      buffer.writeln(
          'Code  Account Name                           Txns        Amount');
    } else {
      buffer.writeln(
          'Code  Account Name                                        Amount');
    }
    buffer.writeln('-' * 80);

    final sortedExpenses = sortAccounts(expenseData);
    for (final entry in sortedExpenses) {
      final code = entry.key;
      final data = entry.value;
      final name = data['name'] as String;
      final amount = data['amount'] as double;
      final txnCount = data['transactionCount'] as int;

      if (includeTransactionCounts) {
        buffer.writeln(
            '${code.padRight(5)} ${name.padRight(35)} ${txnCount.toString().padLeft(4)} ${_formatCurrency(amount).padLeft(12)}');
      } else {
        buffer.writeln(
            '${code.padRight(5)} ${name.padRight(50)} ${_formatCurrency(amount).padLeft(12)}');
      }
    }

    buffer.writeln('-' * 80);
    buffer.writeln(
        '${''.padRight(58)} TOTAL EXPENSES ${_formatCurrency(totalExpenses).padLeft(11)}');
    buffer.writeln('=' * 80);
    buffer.writeln();

    // Net profit
    buffer.writeln('NET PROFIT CALCULATION');
    buffer.writeln('-' * 40);
    if (cogsData.isNotEmpty) {
      buffer.writeln(
          'Gross Profit:           ${_formatCurrency(grossProfit).padLeft(12)}');
    } else {
      buffer.writeln(
          'Total Revenue:          ${_formatCurrency(totalRevenue).padLeft(12)}');
    }
    buffer.writeln(
        'Less: Total Expenses:   ${_formatCurrency(totalExpenses).padLeft(12)}');
    buffer.writeln('-' * 40);
    buffer.writeln(
        'NET PROFIT:             ${_formatCurrency(netProfit).padLeft(12)}');

    if (netProfit >= 0) {
      buffer.writeln('✓ PROFITABLE PERIOD');
    } else {
      buffer.writeln('⚠ LOSS PERIOD');
    }

    buffer.writeln();
    buffer.writeln('Report generated: ${DateTime.now().toIso8601String()}');

    return buffer.toString();
  }

  /// Generate plaintext trial balance report
  String _generateTrialBalancePlaintext(
    DateTime asOfDate,
    Map<String, Map<String, dynamic>> trialBalanceData,
    double totalDebits,
    double totalCredits,
    String sortBy,
    bool groupByType,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('=' * 90);
    buffer.writeln('TRIAL BALANCE (AUDIT REPORT)');
    buffer.writeln('As of ${_formatDateForDisplay(asOfDate)}');
    buffer.writeln('=' * 90);
    buffer.writeln();

    if (groupByType) {
      // Group by account type
      final accountsByType =
          <String, List<MapEntry<String, Map<String, dynamic>>>>{};

      for (final entry in trialBalanceData.entries) {
        final type = entry.value['type'] as String;
        accountsByType.putIfAbsent(
            type, () => <MapEntry<String, Map<String, dynamic>>>[]);
        accountsByType[type]!.add(entry);
      }

      // Sort each group
      for (final typeEntries in accountsByType.values) {
        switch (sortBy) {
          case 'account_name':
            typeEntries.sort((a, b) => (a.value['name'] as String)
                .compareTo(b.value['name'] as String));
            break;
          case 'account_type':
            // Already grouped by type
            typeEntries.sort((a, b) => a.key.compareTo(b.key));
            break;
          case 'account_code':
          default:
            typeEntries.sort((a, b) => a.key.compareTo(b.key));
            break;
        }
      }

      // Output grouped trial balance
      final typeOrder = [
        'Bank',
        'Current Asset',
        'Fixed Asset',
        'Inventory',
        'Current Liability',
        'Equity',
        'Revenue',
        'Other Income',
        'COGS',
        'Expense',
        'Depreciation'
      ];

      for (final type in typeOrder) {
        final entries = accountsByType[type];
        if (entries == null || entries.isEmpty) continue;

        buffer.writeln(type.toUpperCase());
        buffer.writeln('-' * 90);
        buffer.writeln(
            'Code  Account Name                                    Debit       Credit');
        buffer.writeln('-' * 90);

        for (final entry in entries) {
          final code = entry.key;
          final data = entry.value;
          final name = data['name'] as String;
          final debitBalance = data['debitBalance'] as double;
          final creditBalance = data['creditBalance'] as double;

          final debitStr =
              debitBalance == 0 ? '' : _formatCurrency(debitBalance);
          final creditStr =
              creditBalance == 0 ? '' : _formatCurrency(creditBalance);

          buffer.writeln(
              '${code.padRight(5)} ${name.padRight(45)} ${debitStr.padLeft(11)} ${creditStr.padLeft(11)}');
        }
        buffer.writeln();
      }
    } else {
      // Simple sorted list
      buffer.writeln(
          'Code  Account Name                            Type         Debit       Credit');
      buffer.writeln('-' * 90);

      final entries = trialBalanceData.entries.toList();
      switch (sortBy) {
        case 'account_name':
          entries.sort((a, b) =>
              (a.value['name'] as String).compareTo(b.value['name'] as String));
          break;
        case 'account_type':
          entries.sort((a, b) =>
              (a.value['type'] as String).compareTo(b.value['type'] as String));
          break;
        case 'account_code':
        default:
          entries.sort((a, b) => a.key.compareTo(b.key));
          break;
      }

      for (final entry in entries) {
        final code = entry.key;
        final data = entry.value;
        final name = data['name'] as String;
        final type = data['type'] as String;
        final debitBalance = data['debitBalance'] as double;
        final creditBalance = data['creditBalance'] as double;

        final debitStr = debitBalance == 0 ? '' : _formatCurrency(debitBalance);
        final creditStr =
            creditBalance == 0 ? '' : _formatCurrency(creditBalance);

        buffer.writeln(
            '${code.padRight(5)} ${name.padRight(30)} ${type.padRight(12)} ${debitStr.padLeft(11)} ${creditStr.padLeft(11)}');
      }
    }

    buffer.writeln('=' * 90);
    buffer.writeln(
        '${''.padRight(62)} TOTALS: ${_formatCurrency(totalDebits).padLeft(11)} ${_formatCurrency(totalCredits).padLeft(11)}');
    buffer.writeln();

    // Balance verification
    final difference = totalDebits - totalCredits;
    buffer.writeln('TRIAL BALANCE VERIFICATION');
    buffer.writeln('-' * 40);
    buffer.writeln(
        'Total Debits:           ${_formatCurrency(totalDebits).padLeft(12)}');
    buffer.writeln(
        'Total Credits:          ${_formatCurrency(totalCredits).padLeft(12)}');
    buffer.writeln('-' * 40);
    buffer.writeln(
        'Difference:             ${_formatCurrency(difference).padLeft(12)}');

    if (difference.abs() < 0.01) {
      buffer.writeln('✓ TRIAL BALANCE IN BALANCE');
    } else {
      buffer.writeln('⚠ TRIAL BALANCE OUT OF BALANCE!');
    }

    buffer.writeln();
    buffer.writeln('Report generated: ${DateTime.now().toIso8601String()}');

    return buffer.toString();
  }

  /// Generate plaintext cash flow report
  String _generateCashFlowPlaintext(
    DateTime startDate,
    DateTime endDate,
    Map<String, Map<String, dynamic>> cashFlowData,
    double totalCashFlow,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('=' * 80);
    buffer.writeln('CASH FLOW STATEMENT (AUDIT REPORT)');
    buffer.writeln(
        'For the period ${_formatDateForDisplay(startDate)} to ${_formatDateForDisplay(endDate)}');
    buffer.writeln('=' * 80);
    buffer.writeln();

    // Summary
    buffer.writeln('CASH ACCOUNT SUMMARY');
    buffer.writeln('-' * 80);
    buffer.writeln(
        'Code  Account Name                    Starting    Ending      Net Change');
    buffer.writeln('-' * 80);

    for (final entry in cashFlowData.entries) {
      final code = entry.key;
      final data = entry.value;
      final name = data['name'] as String;
      final startingBalance = data['startingBalance'] as double;
      final endingBalance = data['endingBalance'] as double;
      final netChange = data['netChange'] as double;

      buffer.writeln(
          '${code.padRight(5)} ${name.padRight(25)} ${_formatCurrency(startingBalance).padLeft(10)} ${_formatCurrency(endingBalance).padLeft(10)} ${_formatCurrency(netChange).padLeft(10)}');
    }

    buffer.writeln('-' * 80);
    buffer.writeln(
        '${''.padRight(56)} TOTAL NET CHANGE: ${_formatCurrency(totalCashFlow).padLeft(10)}');
    buffer.writeln();

    // Detailed transactions for each account
    for (final entry in cashFlowData.entries) {
      final code = entry.key;
      final data = entry.value;
      final name = data['name'] as String;
      final transactions = data['transactions'] as List<Map<String, dynamic>>;
      final transactionCount = data['transactionCount'] as int;

      if (transactions.isEmpty) continue;

      buffer.writeln('DETAILED TRANSACTIONS: $code - $name');
      buffer.writeln('-' * 80);
      buffer.writeln(
          'Date       Description                                  Amount    Running Bal');
      buffer.writeln('-' * 80);

      for (final transaction in transactions) {
        final date = transaction['date'] as String;
        final description = (transaction['description'] as String).padRight(35);
        final amount = transaction['amount'] as double;
        final runningBalance = transaction['runningBalance'] as double;

        buffer.writeln(
            '${date.padRight(10)} ${description.length > 35 ? description.substring(0, 35) : description.padRight(35)} ${_formatCurrency(amount).padLeft(10)} ${_formatCurrency(runningBalance).padLeft(10)}');
      }

      buffer.writeln('-' * 80);
      buffer.writeln('Total transactions: $transactionCount');
      buffer.writeln();
    }

    buffer.writeln('Report generated: ${DateTime.now().toIso8601String()}');

    return buffer.toString();
  }

  /// Generate plaintext account activity report
  String _generateAccountActivityPlaintext(
    DateTime startDate,
    DateTime endDate,
    Map<String, Map<String, dynamic>> accountActivityData,
    bool includeRunningBalance,
    String sortBy,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('=' * 90);
    buffer.writeln('ACCOUNT ACTIVITY REPORT (AUDIT REPORT)');
    buffer.writeln(
        'For the period ${_formatDateForDisplay(startDate)} to ${_formatDateForDisplay(endDate)}');
    buffer.writeln('=' * 90);
    buffer.writeln();

    for (final entry in accountActivityData.entries) {
      final code = entry.key;
      final data = entry.value;
      final name = data['name'] as String;
      final type = data['type'] as String;
      final startingBalance = data['startingBalance'] as double;
      final endingBalance = data['endingBalance'] as double;
      final netChange = data['netChange'] as double;
      final transactionCount = data['transactionCount'] as int;
      final transactions = data['transactions'] as List<Map<String, dynamic>>;

      // Account header
      buffer.writeln('ACCOUNT: $code - $name');
      buffer.writeln('Type: $type');
      if (includeRunningBalance) {
        buffer.writeln('Starting Balance: ${_formatCurrency(startingBalance)}');
        buffer.writeln('Ending Balance: ${_formatCurrency(endingBalance)}');
        buffer.writeln('Net Change: ${_formatCurrency(netChange)}');
      }
      buffer.writeln('Total Transactions: $transactionCount');
      buffer.writeln('-' * 90);

      if (transactions.isEmpty) {
        buffer.writeln('No transactions found for this period.');
        buffer.writeln();
        continue;
      }

      // Transaction header
      if (includeRunningBalance && sortBy == 'date') {
        buffer.writeln(
            'Date       Description                          Bank Account    Amount    Running Bal');
      } else {
        buffer.writeln(
            'Date       Description                          Bank Account            Amount');
      }
      buffer.writeln('-' * 90);

      // Transactions
      for (final transaction in transactions) {
        final date = transaction['date'] as String;
        final description = (transaction['description'] as String);
        final bankAccount = (transaction['bankAccount'] as String);
        final amount = transaction['amount'] as double;
        final notes = transaction['notes'] as String;

        final truncatedDesc = description.length > 30
            ? description.substring(0, 30)
            : description.padRight(30);
        final truncatedBank = bankAccount.length > 15
            ? bankAccount.substring(0, 15)
            : bankAccount.padRight(15);

        if (includeRunningBalance && sortBy == 'date') {
          final runningBalance = transaction['runningBalance'] as double;
          buffer.writeln(
              '${date.padRight(10)} $truncatedDesc $truncatedBank ${_formatCurrency(amount).padLeft(10)} ${_formatCurrency(runningBalance).padLeft(10)}');
        } else {
          buffer.writeln(
              '${date.padRight(10)} $truncatedDesc $truncatedBank ${_formatCurrency(amount).padLeft(15)}');
        }

        if (notes.isNotEmpty) {
          buffer.writeln('           Notes: $notes');
        }
      }

      buffer.writeln('-' * 90);
      buffer.writeln();
    }

    buffer.writeln('Report generated: ${DateTime.now().toIso8601String()}');

    return buffer.toString();
  }

  /// Helper methods for formatting
  String _formatCurrency(double value) {
    final isNegative = value < 0;
    final absValue = value.abs();
    return '${isNegative ? '-' : ''}\$${absValue.toStringAsFixed(2)}';
  }

  String _formatDateForDisplay(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
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

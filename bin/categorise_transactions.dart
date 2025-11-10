import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/services/services.dart';
import 'package:ai_accounting/services/transaction_categorizer.dart';
import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:path/path.dart' as path;

final projectRoot = Directory.current.path;
final configDir = Directory(Platform.environment['AI_ACCOUNTING_CONFIG_DIR'] ??
    path.join(projectRoot, 'config'));
final inputsDir = Directory(Platform.environment['AI_ACCOUNTING_INPUTS_DIR'] ??
    path.join(projectRoot, 'inputs'));
final dataDir = Directory(Platform.environment['AI_ACCOUNTING_DATA_DIR'] ??
    path.join(projectRoot, 'data'));

// DRY: Define config file paths once
final supplierListPath = path.join(inputsDir.path, "supplier_list.json");
final chartOfAccountsPath = path.join(inputsDir.path, "accounts.json");
final companyProfilePath = path.join(inputsDir.path, 'company_profile.txt');
final accountingRulesPath = path.join(inputsDir.path, 'accounting_rules.txt');

// UNCATEGORIZED ACCOUNT CODE - All new transactions startuncategor here
const String uncategorizedAccountCode = '999';

Future<void> main() async {
  print('🤖 Starting AI Transaction Categorization Workflow...');

  // === INITIALIZATION PHASE ===
  final apiKey = Platform.environment['DEEPSEEK_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    throw Exception("DEEPSEEK_API_KEY is not set");
  }

  final mcpConfig = File(path.join(configDir.path, "mcp_servers.json"));
  final client =
      ApiClient(baseUrl: "https://api.deepseek.com/v1", apiKey: apiKey);
  final toolRegistry = McpToolExecutorRegistry(mcpConfig: mcpConfig);
  await toolRegistry.initialize();
  _verifyRequiredTools(toolRegistry);

  // Ensure config files exist, create if missing
  _ensureConfigFilesExist();

  // Use global services singleton to ensure consistency with MCP server
  // This fixes the persistence issue where script and MCP used different instances

  // === STEP 1: CATEGORIZE UNCATEGORIZED TRANSACTIONS (ACCOUNT 999) ===
  print(
      '🔍 Step 1: Loading uncategorized transactions for AI categorization...');

  // Find all journal entries with account 999 (uncategorized)
  final uncategorizedEntries = services.generalJournal.entries
      .where((entry) =>
          entry.debits.any((d) => d.accountCode == uncategorizedAccountCode) ||
          entry.credits.any((c) => c.accountCode == uncategorizedAccountCode))
      .toList();

  print('🎯 Found ${uncategorizedEntries.length} uncategorized transactions');

  if (uncategorizedEntries.isNotEmpty) {
    // Process transactions one at a time for better reliability and debugging
    int categorizedCount = 0;

    // Config files are loaded by MCP server as needed

    print(
        '🔄 Processing ${uncategorizedEntries.length} transactions individually...');

    for (int i = 0; i < uncategorizedEntries.length; i++) {
      final entry = uncategorizedEntries[i];
      final transactionNumber = i + 1;

      print(
          '\n📄 Processing transaction $transactionNumber/${uncategorizedEntries.length}:');
      print('   💰 Amount: \$${entry.amount}');
      print('   📝 Description: ${entry.description}');

      try {
        // Create transaction ID in the format expected by MCP tools
        final transactionId =
            '${entry.date.toIso8601String().substring(0, 10)}_${entry.description}_${entry.amount}_${entry.bankCode}';

        // Determine transaction type
        final isBankDebit =
            entry.debits.any((d) => d.accountCode == entry.bankCode);
        final isIncomeTransaction = isBankDebit; // Bank debit = income

        print('   🔄 Matching supplier...');

        // Step 1: Use match_supplier_fuzzy to identify the supplier
        final supplierMatchCall = ToolCall(
          id: 'match_${DateTime.now().millisecondsSinceEpoch}',
          type: 'function',
          function: ToolCallFunction(
            name: 'match_supplier_fuzzy',
            arguments: jsonEncode({
              'transactionDescription': entry.description,
              'isIncomeTransaction': isIncomeTransaction,
            }),
          ),
        );

        final supplierResultString =
            await toolRegistry.executeTool(supplierMatchCall);
        final supplierResult = jsonDecode(supplierResultString);

        if (supplierResult['success'] != true) {
          print('   ⚠️  Supplier matching failed, skipping transaction');
          continue;
        }

        final supplier = supplierResult['supplier'] as Map<String, dynamic>?;
        final confidence = supplierResult['confidence'] as double? ?? 0.0;
        final supplierName = supplier?['name'] as String? ?? 'Unknown';
        final supplies = supplier?['supplies'] as String? ?? 'Unknown';

        print(
            '   📊 Supplier: $supplierName (${(confidence * 100).toStringAsFixed(1)}% confidence)');
        print('   🏪 Supplies: $supplies');

        // Step 2: Determine account based on supplier and business rules
        String newAccountCode = '999'; // Default to uncategorized
        String justification = 'Could not determine appropriate account';

        // Simple account mapping based on transaction type and supplier info
        if (isIncomeTransaction) {
          final incomeDecision = categorizeIncomeTransaction(
            supplierName: supplierName,
            suppliesDescription: supplies,
          );
          newAccountCode = incomeDecision.accountCode;
          justification = incomeDecision.justification;
        } else {
          final expenseDecision = categorizeExpenseTransaction(
            supplierName: supplierName,
            suppliesDescription: supplies,
          );
          newAccountCode = expenseDecision.accountCode;
          justification = expenseDecision.justification;
        }

        // Step 3: Update the transaction account if we have a valid mapping
        if (newAccountCode != '999') {
          print(
              '   🎯 Categorizing to account $newAccountCode: $justification');

          final enhancedNotes =
              'AI categorization: $justification | Supplier: $supplierName (confidence: ${(confidence * 100).toStringAsFixed(1)}%)';

          final updateCall = ToolCall(
            id: 'update_${DateTime.now().millisecondsSinceEpoch}',
            type: 'function',
            function: ToolCallFunction(
              name: 'update_transaction_account',
              arguments: jsonEncode({
                'transactionId': transactionId,
                'newAccountCode': newAccountCode,
                'notes': enhancedNotes,
              }),
            ),
          );

          final updateResultString = await toolRegistry.executeTool(updateCall);
          final updateResult = jsonDecode(updateResultString);

          if (updateResult['success'] == true) {
            print('   ✅ Successfully categorized -> Account $newAccountCode');
            categorizedCount++;
          } else {
            print(
                '   ❌ Failed to update: ${updateResult['message'] ?? 'Unknown error'}');
          }
        } else {
          print(
              '   ⚠️  Could not determine appropriate account, leaving uncategorized');
        }
      } catch (e) {
        print('   ❌ Error processing transaction: $e');
      }
    }

    print(
        '✅ Categorization complete: $categorizedCount transactions processed');
  } else {
    print(
        '✨ No uncategorized transactions found - all transactions are already categorized!');
  }

  print('\n🏆 Single Transaction Processing Complete!');
  print('🎯 IMPROVEMENTS MADE:');
  print('  ⚡ One-by-one processing for better reliability');
  print('  🧠 AI-powered fuzzy supplier matching per transaction');
  print('  🔧 Fixed Services singleton issue for proper persistence');
  print('  📊 Real-time progress tracking and detailed logging');
  print('💡 NEXT STEPS:');
  print(
      '  📊 Run "dart run bin/generate_reports.dart" to generate financial reports');
  print(
      '  📥 Run "dart run bin/import_transactions.dart" to import new CSV files');
  print(
      '  🗑️  Run "dart run bin/cleanup_uncategorized.dart" to clean up bad imports');

  await toolRegistry.shutdown();
  await client.close();
  exit(0);
}

/// Ensures all required configuration files exist, creating them if missing
void _ensureConfigFilesExist() {
  final supplierListFile = File(supplierListPath);
  if (!supplierListFile.existsSync()) {
    supplierListFile.createSync(recursive: true);
    supplierListFile.writeAsStringSync('[]');
    print('📝 Created supplier list file: $supplierListPath');
  }

  final chartOfAccountsFile = File(chartOfAccountsPath);
  if (!chartOfAccountsFile.existsSync()) {
    chartOfAccountsFile.createSync(recursive: true);
    chartOfAccountsFile.writeAsStringSync('[]');
    print('📝 Created chart of accounts file: $chartOfAccountsPath');
  }

  final companyProfileFile = File(companyProfilePath);
  if (!companyProfileFile.existsSync()) {
    companyProfileFile.createSync(recursive: true);
    companyProfileFile.writeAsStringSync('Company profile not configured');
    print('📝 Created company profile file: $companyProfilePath');
  }

  final accountingRulesFile = File(accountingRulesPath);
  if (!accountingRulesFile.existsSync()) {
    accountingRulesFile.createSync(recursive: true);
    accountingRulesFile.writeAsStringSync(
        'No specific accounting rules defined yet.\nUse the Accountant MCP Server to add institutional knowledge for better transaction categorization.');
    print('📝 Created accounting rules file: $accountingRulesPath');
  }
}

/// Validates that all required MCP tools are registered before categorisation.
void _verifyRequiredTools(McpToolExecutorRegistry registry) {
  const requiredTools = <String>{
    'match_supplier_fuzzy',
    'update_transaction_account',
  };

  final missingTools = requiredTools
      .where((toolName) => !registry.executors.containsKey(toolName))
      .toList();

  if (missingTools.isNotEmpty) {
    final missingList = missingTools.join(', ');
    throw Exception(
      'Required MCP tools missing: $missingList. '
      'Ensure the accountant MCP server is registered in config/mcp_servers.json.',
    );
  }
}

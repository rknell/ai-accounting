import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/split_transaction.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:path/path.dart' as path;

final projectRoot = Directory.current.path;
final configDir = Directory(path.join(projectRoot, 'config'));
final inputsDir = Directory(path.join(projectRoot, 'inputs'));

// DRY: Define config file paths once
final supplierListPath = path.join(inputsDir.path, "supplier_list.json");
final chartOfAccountsPath = path.join(inputsDir.path, "accounts.json");
final companyProfilePath = path.join(inputsDir.path, 'company_profile.txt');
final accountingRulesPath = path.join(inputsDir.path, 'accounting_rules.txt');

// UNCATEGORIZED ACCOUNT CODE - All new transactions startuncategor here
const String uncategorizedAccountCode = '999';

// --- SYSTEM PROMPT BUILDER ---
String buildSystemPrompt(
    {required String companyProfile,
    required String supplierList,
    required String chartOfAccounts,
    required String accountingRules,
    required String companyProfilePath,
    required String supplierListPath,
    required String chartOfAccountsPath,
    required String accountingRulesPath}) {
  return """
    Your job is to take lines on a bank statement and correctly categorise them to an account.
    Use the chart of accounts and the supplier list to categorise the lines.
    
    CRITICAL: Before researching any supplier, check if it already exists in the known supplier list using FUZZY MATCHING:
    - Match partial names (e.g., "linkt" matches "Linkt Brisbane")
    - Ignore prefixes like "Sp ", "Visa Purchase", location codes, store numbers
    - Match core business names (e.g., "Dtf Direct" matches "DTF Direct")
    - Match variations (e.g., "cursor" matches "Cursor, Ai Powered")
    
    You can use the read_supplier tool to check if a supplier exists with fuzzy matching.
    The tool will return "found": true if a supplier exists, or "found": false with a suggestion to research.
    
    ONLY research suppliers when read_supplier returns "found": false.
    
    If a supplier is genuinely not in the known supplier list, follow this workflow:
    1. Use puppeteer_navigate to go to "https://duckduckgo.com/?q=[supplier name]"
    2. The puppeteer_navigate tool will automatically return the page's innerText content
    3. Analyze the search results to understand what the supplier does and how it applies to the company.
    4. If the supplier name should be cleaned up given the search results, do so and continue to reference it with the cleaned up name.
    For example strip identifiers from the name such as numbers or locations, just keep the business name.
    5. Use the create_supplier tool to add the new supplier with their cleaned name and what they supply.

    If something is increasing the bank account (cr) just consider it a sale.

    If after researching you are still unsure which account it should go in, leave it as "Unknown".
    MANDATORY: You must categorise all provided line items before completing the task.
    Use the company profile to help you understand the company and its operations.
    
    PRIORITY: Follow these institutional accounting rules first before applying general logic:
    Accounting Rules (from $accountingRulesPath):
    $accountingRules
    
    Company Profile (from $companyProfilePath):
    $companyProfile
    Known Suppliers (from $supplierListPath):
    $supplierList
    Chart of accounts (from $chartOfAccountsPath):
    $chartOfAccounts
    Assume all transactions are business expenses and try to find a likely justification for each one.
    
    MANDATORY: Response must be in JSON format and only include the JSON object. Do not include any other text. 
    
    Each input line contains a TransactionID at the end that you MUST extract and include in your response.
    
    Response format:
    [
      {
        "account": "501",
        "supplierName": "7-Eleven", 
        "lineItem": "20/12/2024\tVisa Purchase 17Dec 7-Eleven 4210 Ormeau Ormeau\t130.48\t232939.4\tTransactionID:2024-12-20_Visa Purchase 17Dec 7-Eleven 4210 Ormeau Ormeau_130.48_001",
        "justification": "The purchase of fuel",
        "transactionId": "2024-12-20_Visa Purchase 17Dec 7-Eleven 4210 Ormeau Ormeau_130.48_001"
      }
    ]
    
    CRITICAL: Extract the transactionId from the TransactionID field in each input line and include it exactly in your response.
    This will be used to update the transaction using the update_transaction_account tool.
  """;
}

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

  // Ensure config files exist, create if missing
  _ensureConfigFilesExist();

  final services = Services();

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
    // Convert journal entries back to statement lines for AI processing
    final uncategorizedRows = <Map<String, dynamic>>[];

    for (final entry in uncategorizedEntries) {
      // Create transaction ID in the format expected by MCP tools
      final transactionId =
          '${entry.date.toIso8601String().substring(0, 10)}_${entry.description}_${entry.amount}_${entry.bankCode}';

      // 🛡️ WARRIOR PRINCIPLE: All amounts are positive, debit/credit determines direction
      // Determine if this is a debit or credit to the bank account based on transaction structure
      final isBankDebit =
          entry.debits.any((d) => d.accountCode == entry.bankCode);

      // Create a pseudo-row for AI processing with transaction ID
      final statementLine = isBankDebit
          ? '${entry.date.toIso8601String().substring(0, 10)}\t${entry.description}\t${entry.amount}\t\t${entry.bankBalance}\tTransactionID:$transactionId'
          : '${entry.date.toIso8601String().substring(0, 10)}\t${entry.description}\t\t${entry.amount}\t${entry.bankBalance}\tTransactionID:$transactionId';

      uncategorizedRows.add({
        'entry': entry,
        'statementLine': statementLine,
        'transactionId': transactionId,
      });
    }

    // Process in batches of 10 with refreshed system prompt
    int categorizedCount = 0;
    for (var i = 0; i < uncategorizedRows.length; i += 10) {
      final batch = uncategorizedRows.skip(i).take(10).toList();
      final batchNumber = (i ~/ 10) + 1;
      final totalBatches = ((uncategorizedRows.length - 1) ~/ 10) + 1;

      print(
          '📦 Processing batch $batchNumber of $totalBatches (${batch.length} transactions)...');

      // 🔄 REFRESH SYSTEM PROMPT FOR EACH BATCH
      // This ensures the agent has the latest supplier list, chart of accounts, and accounting rules
      print('  🔄 Refreshing system prompt with latest data...');
      final supplierList = File(supplierListPath).readAsStringSync();
      final chartOfAccounts = File(chartOfAccountsPath).readAsStringSync();
      final companyProfile = File(companyProfilePath).readAsStringSync();

      // Load accounting rules if they exist
      String accountingRules = 'No specific accounting rules defined yet.';
      final accountingRulesFile = File(accountingRulesPath);
      if (accountingRulesFile.existsSync()) {
        accountingRules = accountingRulesFile.readAsStringSync();
      }

      final systemPrompt = buildSystemPrompt(
        companyProfile: companyProfile,
        supplierList: supplierList,
        chartOfAccounts: chartOfAccounts,
        accountingRules: accountingRules,
        companyProfilePath: companyProfilePath,
        supplierListPath: supplierListPath,
        chartOfAccountsPath: chartOfAccountsPath,
        accountingRulesPath: accountingRulesPath,
      );

      final agent = Agent.withFilteredTools(
        apiClient: client,
        toolRegistry: toolRegistry,
        systemPrompt: systemPrompt,
        allowedToolNames: {
          'puppeteer_navigate',
          // MCP Accountant tools for supplier management and transaction updates
          'create_supplier',
          'update_supplier',
          'read_supplier',
          'list_suppliers',
          'update_transaction_account',
          'search_transactions_by_account',
        },
      )..temperature = 0.3;

      final lines = batch.map((e) => e['statementLine'] as String).join("\n");

      try {
        final result = await agent.sendMessage(lines);
        final rawContent = result.content?.trim() ?? '';

        if (rawContent.isEmpty) {
          print('⚠️  Empty response from AI for batch $batchNumber');
          continue;
        }

        // Clean JSON response - remove markdown formatting if present
        String cleanedJson = rawContent;
        if (cleanedJson.startsWith('```json')) {
          cleanedJson = cleanedJson.replaceFirst('```json', '').trim();
        }
        if (cleanedJson.startsWith('```')) {
          cleanedJson = cleanedJson.replaceFirst('```', '').trim();
        }
        if (cleanedJson.endsWith('```')) {
          cleanedJson = cleanedJson
              .replaceRange(
                  cleanedJson.lastIndexOf('```'), cleanedJson.length, '')
              .trim();
        }

        final List<dynamic> jsonList =
            (jsonDecode(cleanedJson) as List<dynamic>);

        for (final item in jsonList) {
          final lineItem = item['lineItem'] as String?;
          final newAccount = item['account'] as String? ?? '';
          final justification = item['justification'] as String?;
          final transactionId = item['transactionId'] as String?;

          if (transactionId != null &&
              newAccount.isNotEmpty &&
              newAccount != uncategorizedAccountCode) {
            try {
              // Use MCP tool to update the transaction account
              final toolCall = ToolCall(
                id: 'update_${DateTime.now().millisecondsSinceEpoch}',
                type: 'function',
                function: ToolCallFunction(
                  name: 'update_transaction_account',
                  arguments: jsonEncode({
                    'transactionId': transactionId,
                    'newAccountCode': newAccount,
                    'notes':
                        justification ?? 'AI categorization: $justification',
                  }),
                ),
              );

              final updateResultString =
                  await toolRegistry.executeTool(toolCall);
              final updateResult = jsonDecode(updateResultString);

              if (updateResult['success'] == true) {
                print(
                    '  ✅ Categorized via MCP: $transactionId -> Account $newAccount ($justification)');
                categorizedCount++;
              } else {
                print(
                    '  ⚠️  MCP update failed for $transactionId: ${updateResult['message'] ?? 'Unknown error'}');
              }
            } catch (e) {
              print(
                  '  ❌ Error updating transaction $transactionId via MCP: $e');

              // Fallback to direct update if MCP fails
              final match = batch.firstWhere(
                (e) => e['statementLine'] == lineItem,
                orElse: () => <String, dynamic>{},
              );

              if (match.isNotEmpty) {
                final originalEntry = match['entry'] as GeneralJournal;
                final updatedEntry = _updateEntryAccountCode(
                    originalEntry, newAccount, justification ?? '');

                final wasUpdated = services.generalJournal
                    .updateEntry(originalEntry, updatedEntry);

                if (wasUpdated) {
                  print(
                      '  ✅ Fallback categorized: ${originalEntry.description} -> Account $newAccount ($justification)');
                  categorizedCount++;
                } else {
                  print(
                      '  ⚠️  Failed to update entry: ${originalEntry.description}');
                }
              }
            }
          } else if (transactionId == null) {
            print('  ⚠️  Missing transactionId in AI response: $item');
          }
        }

        // Note: Supplier updates are now handled automatically via the create_supplier tool
        // during the categorization process, so no additional supplier list update is needed.
        print(
            '  📝 Supplier list automatically updated via MCP tools during categorization');
      } catch (e, s) {
        print('❌ Error processing batch $batchNumber: $e');
        if (s.toString().isNotEmpty) {
          print('Stack trace: $s');
        }
      }
    }

    print(
        '✅ Categorization complete: $categorizedCount transactions processed');
  } else {
    print(
        '✨ No uncategorized transactions found - all transactions are already categorized!');
  }

  print('🏆 AI Transaction Categorization Complete!');
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

/// Updates a journal entry's account code from 999 (uncategorized) to a proper account
///
/// Creates a new GeneralJournal entry with the uncategorized account (999) replaced
/// with the new account code, maintaining all other transaction details.
///
/// @param originalEntry The entry to update
/// @param newAccountCode The new account code to assign
/// @param justification The reasoning for the categorization
/// @return A new GeneralJournal entry with updated account code
GeneralJournal _updateEntryAccountCode(
    GeneralJournal originalEntry, String newAccountCode, String justification) {
  // Update debits - replace account 999 with new account code
  final updatedDebits = originalEntry.debits.map((debit) {
    if (debit.accountCode == uncategorizedAccountCode) {
      return SplitTransaction(
          accountCode: newAccountCode, amount: debit.amount);
    }
    return debit;
  }).toList();

  // Update credits - replace account 999 with new account code
  final updatedCredits = originalEntry.credits.map((credit) {
    if (credit.accountCode == uncategorizedAccountCode) {
      return SplitTransaction(
          accountCode: newAccountCode, amount: credit.amount);
    }
    return credit;
  }).toList();

  // Create new entry with updated account codes
  return GeneralJournal(
    date: originalEntry.date,
    description: originalEntry.description,
    debits: updatedDebits,
    credits: updatedCredits,
    bankBalance: originalEntry.bankBalance,
    notes: justification.isNotEmpty ? justification : originalEntry.notes,
  );
}

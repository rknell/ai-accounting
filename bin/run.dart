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

// UNCATEGORIZED ACCOUNT CODE - All new transactions start here
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
    
    ONLY research suppliers that have NO MATCH in the existing supplier list.
    
    If a supplier is genuinely not in the known supplier list, follow this workflow:
    1. Use puppeteer_navigate to go to "https://duckduckgo.com/?q=[supplier name]"
    2. The puppeteer_navigate tool will automatically return the page's innerText content
    3. Analyze the search results to understand what the supplier does and how it applies to the company.
    4. If the supplier name should be cleaned up given the search results, do so and continue to reference it with the cleaned up name.
    For example strip identifiers from the name such as numbers or locations, just keep the business name.

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
    MANDATORY: Response must be in JSON format and only include the JSON object. Do not include any other text. Response format:
    [
      {
        "account": "501",
        "supplierName": "7-Eleven",
        "lineItem": "20/12/2024\tVisa Purchase 17Dec 7-Eleven 4210 Ormeau Ormeau\t130.48\t232939.4",
        "justification": "The purchase of fuel"
      }
    ]
  """;
}

Future<void> main() async {
  print('🚀 Starting AI Accounting Workflow...');

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

  // === STEP 1: IMPORT ALL BANK STATEMENT CSV FILES ===
  print('📊 Step 1: Importing bank statement CSV files...');
  final bankImportFiles = services.bankStatement.loadBankImportFiles();
  print('✅ Loaded ${bankImportFiles.length} bank import files');

  // === STEP 2: ADD NEW TRANSACTIONS TO GENERAL JOURNAL WITH ACCOUNT 999 ===
  print('💾 Step 2: Adding new transactions to general journal...');
  int newTransactionsAdded = 0;

  for (final bankFile in bankImportFiles) {
    for (final row in bankFile.rawFileRows) {
      // Set uncategorized account code for new transactions
      if (row.accountCode.isEmpty) {
        row.accountCode = uncategorizedAccountCode;
        row.reason = 'Imported - needs categorization';
      }

      // Create journal entry from the row
      final journalEntry = GeneralJournal.fromRawFileRow(row);

      // Add to general journal (this will handle duplicate checking)
      final wasAdded = services.generalJournal.addEntry(journalEntry);
      if (wasAdded) {
        newTransactionsAdded++;
        print('  ➕ Added: ${row.description} (${row.accountCode})');
      }
    }
  }

  print('✅ Added $newTransactionsAdded new transactions to general journal');

  // === STEP 3: CATEGORIZE UNCATEGORIZED TRANSACTIONS (ACCOUNT 999) ===
  print('🤖 Step 3: AI categorization of uncategorized transactions...');

  // Find all journal entries with account 999 (uncategorized)
  final uncategorizedEntries = services.generalJournal.entries
      .where((entry) =>
          entry.debits.any((d) => d.accountCode == uncategorizedAccountCode) ||
          entry.credits.any((c) => c.accountCode == uncategorizedAccountCode))
      .toList();

  print('🔍 Found ${uncategorizedEntries.length} uncategorized transactions');

  if (uncategorizedEntries.isNotEmpty) {
    // Convert journal entries back to statement lines for AI processing
    final uncategorizedRows = <Map<String, dynamic>>[];

    for (final entry in uncategorizedEntries) {
      // Create a pseudo-row for AI processing
      final statementLine =
          '${entry.date.toIso8601String().substring(0, 10)}\t${entry.description}\t${entry.amount > 0 ? entry.amount.toString() : ''}\t${entry.amount < 0 ? (-entry.amount).toString() : ''}\t${entry.bankBalance}';

      uncategorizedRows.add({
        'entry': entry,
        'statementLine': statementLine,
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
          'read_file',
          'read_text_file',
          'write_file',
          'edit_file',
          'create_directory',
          'list_directory',
          'list_directory_with_sizes',
          'directory_tree',
          'move_file',
          'search_files',
          'get_file_info',
          'list_allowed_directories',
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

          // Find matching entry in this batch
          final match = batch.firstWhere(
            (e) => e['statementLine'] == lineItem,
            orElse: () => <String, dynamic>{},
          );

          if (match.isNotEmpty &&
              newAccount.isNotEmpty &&
              newAccount != uncategorizedAccountCode) {
            final originalEntry = match['entry'] as GeneralJournal;

            // Create updated entry with new account code
            final updatedEntry = _updateEntryAccountCode(
                originalEntry, newAccount, justification ?? '');

            // Replace the original entry with the updated one
            final wasUpdated = services.generalJournal
                .updateEntry(originalEntry, updatedEntry);

            if (wasUpdated) {
              print(
                  '  ✅ Categorized: ${originalEntry.description} -> Account $newAccount ($justification)');
              categorizedCount++;
            } else {
              print(
                  '  ⚠️  Failed to update entry: ${originalEntry.description}');
            }
          } else if (match.isEmpty) {
            print('  ⚠️  Could not match AI result to transaction: $item');
          }
        }

        // Update supplier list after each batch
        try {
          final supplierUpdate = await agent.sendMessage(
              """Please update ./inputs/supplier_list.json with any new suppliers you researched in this batch.
              
              IMPORTANT: Add suppliers using their CLEANED business names (not the raw transaction text).
              For example:
              - Transaction "Sp Dtf Direct" -> Add "DTF Direct" 
              - Transaction "linkt" -> Add "Linkt Brisbane"
              - Transaction "cursor" -> Add "Cursor, Ai Powered"
              
              This prevents future re-research of the same suppliers.""");
          if (supplierUpdate.content?.isNotEmpty == true) {
            print('  📝 Updated supplier list with cleaned names');
          }
        } catch (e) {
          print('  ⚠️  Error updating supplier list: $e');
        }
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
    print('✅ No uncategorized transactions found');
  }

  // === STEP 4: GENERATE REPORTS ===
  print('📊 Step 4: Generating financial reports...');
  services.reportGeneration.generateReports();

  print('🏆 AI Accounting Workflow Complete!');
  print('📈 Check the data/ directory for generated reports');
  print('🌐 Open data/report_viewer.html to view all reports');

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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/ai_query_result.dart';
import 'package:ai_accounting/models/bank_import_models.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';
import 'package:ai_accounting/services/services.dart';

/// A service that batches and debounces requests to get account codes.
///
/// This class collects transaction requests and processes them in batches to optimize
/// API calls to the AI service. It implements debouncing to wait for a short period
/// before processing, allowing multiple requests to be grouped together.
class AccountCodeService {
  /// Singleton instance of the service
  static final AccountCodeService _instance = AccountCodeService._();

  /// Factory constructor that returns the singleton instance
  factory AccountCodeService() => _instance;

  /// Private constructor for singleton pattern
  AccountCodeService._() {
    _loadCache();
  }

  /// Maximum batch size for processing transactions
  final int _maxBatchSize = 20;

  /// Debounce duration before processing a batch
  final Duration _debounceDuration = Duration(milliseconds: 500);

  /// Timer for implementing debounce functionality
  Timer? _debounceTimer;

  /// Queue of pending transactions to be processed
  final List<_PendingTransaction> _pendingTransactions = [];

  /// Flag to track if a batch is currently being processed
  bool _isProcessing = false;

  /// Cache of AI responses keyed by cleaned description
  final Map<String, AIQueryResult> _cache = {};

  /// Path to the cache file
  static const String _cacheFilePath = 'inputs/cached_code_matches.json';

  /// Loads the cache from the JSON file
  void _loadCache() {
    try {
      final file = File(_cacheFilePath);
      if (file.existsSync()) {
        final jsonString = file.readAsStringSync();
        if (jsonString.isNotEmpty) {
          final Map<String, dynamic> jsonMap =
              jsonDecode(jsonString) as Map<String, dynamic>;
          _cache.clear();
          jsonMap.forEach((key, value) {
            var rule = AIQueryResult.fromJson(value as Map<String, dynamic>);
            // Only cache account codes that exist and are income/revenue or expense types
            final account =
                services.chartOfAccounts.getAccount(rule.accountCode);
            if (account != null &&
                (account.type == AccountType.cogs ||
                    account.type == AccountType.revenue ||
                    account.type == AccountType.expense ||
                    account.type == AccountType.otherIncome ||
                    account.code == "701")) {
              _cache[key] = rule;
            }
          });
        }
      }
    } catch (e) {
      print('Error loading cache: $e');
    }
  }

  /// Saves the cache to the JSON file
  void _saveCache() {
    try {
      final file = File(_cacheFilePath);
      final Map<String, dynamic> jsonMap = {};
      _cache.forEach((key, value) {
        jsonMap[key] = value.toJson();
      });
      file.writeAsStringSync(jsonEncode(jsonMap));
    } catch (e) {
      print('Error saving cache: $e');
    }
  }

  /// Adds a transaction to the batch queue and returns a Future that will complete
  /// when the transaction has been processed.
  ///
  /// @param transaction The transaction to be processed
  /// @return A Future that resolves with the AIQueryResult for the transaction
  Future<AIQueryResult> getAccountCode(RawFileRow transaction) {
    // Check cache first
    if (_cache.containsKey(transaction.cleanedDescription)) {
      return Future.value(_cache[transaction.cleanedDescription]);
    }

    // Create a completer to return a Future that will be resolved later
    final completer = Completer<AIQueryResult>();

    // Add the transaction and its completer to the pending queue
    _pendingTransactions.add(_PendingTransaction(
      transaction: transaction,
      completer: completer,
    ));

    // Cancel any existing timer to implement debouncing
    _debounceTimer?.cancel();

    // Start a new timer to process the batch after the debounce period
    _debounceTimer = Timer(_debounceDuration, _processBatch);

    // Return the Future that will be completed when processing is done
    return completer.future;
  }

  /// Processes the pending transactions in batches.
  ///
  /// This method is called after the debounce period and processes transactions
  /// in batches of up to _maxBatchSize. It ensures only one batch is processed
  /// at a time to prevent overwhelming the AI service.
  void _processBatch() async {
    // If already processing or no pending transactions, do nothing
    if (_isProcessing || _pendingTransactions.isEmpty) return;

    // Set the processing flag to prevent concurrent processing
    _isProcessing = true;

    try {
      // Process batches until all pending transactions are handled
      while (_pendingTransactions.isNotEmpty) {
        // Take up to _maxBatchSize transactions from the pending queue
        final currentBatch = _pendingTransactions.take(_maxBatchSize).toList();
        final transactions = currentBatch.map((pt) => pt.transaction).toList();

        // Remove the processed transactions from the pending queue
        _pendingTransactions.removeRange(
            0, min(currentBatch.length, _pendingTransactions.length));

        // Get account codes for the batch from the AI service
        final results = await _getAccountCodes(transactions);

        // Match results with their corresponding transactions and complete the futures
        for (int i = 0; i < currentBatch.length; i++) {
          if (i < results.length) {
            currentBatch[i].completer.complete(results[i]);
          } else {
            // Handle case where fewer results than expected were returned
            currentBatch[i].completer.completeError(
                Exception('Failed to get account code for transaction'));
          }
        }
      }
    } catch (e) {
      // If an error occurs, fail all pending transactions in the current batch
      for (final pending in _pendingTransactions) {
        pending.completer.completeError(e);
      }
      _pendingTransactions.clear();
    } finally {
      // Reset the processing flag when done
      _isProcessing = false;
    }
  }

  Future<List<AIQueryResult>> _getAccountCodes(
      List<RawFileRow> allTransactions) async {
    // Filter out transactions that are already in cache
    final uncachedTransactions = allTransactions
        .where((t) => !_cache.containsKey(t.cleanedDescription))
        .toList();

    if (uncachedTransactions.isEmpty) {
      // If all transactions are cached, return cached results
      return allTransactions.map((t) => _cache[t.cleanedDescription]!).toList();
    }

    var output = StringBuffer();
    _buildAiQueryHeader(output);

    if (uncachedTransactions.isNotEmpty) {
      // Use uncached transactions for AI processing
      final random = Random();
      final rowCount = uncachedTransactions.length;
      final sampleSize = min(40, rowCount);

      output.writeln('\nSample Transactions CSV:');
      output.writeln('Date,Description,Debit,Credit');

      final selectedIndices = <int>{};
      while (selectedIndices.length < sampleSize) {
        selectedIndices.add(random.nextInt(rowCount));
      }

      for (final index in selectedIndices) {
        final row = uncachedTransactions[index];
        output.writeln(
            '${row.date},${row.cleanedDescription},${row.debit},${row.credit}');
      }

      output.writeln(
          "IMPORTANT: respond with a JSON array of objects, each containing 'accountCode', 'description', and 'reasoning' fields. Description is a verbatim copy of the description you are responding to for matching purposes. For example: [{\"accountCode\": \"6000\", \"description\": \"<VERBATIM DESCRIPTION FOR MATCHING>\", \"reasoning\": \"This appears to be income from sales\"}, {\"accountCode\": \"5000\", \"description\": \"OFFICE SUPPLIES\", \"reasoning\": \"Purchase of business supplies\"}]");
      services.deepseekClient.clearContext();
      var result =
          await services.deepseekClient.sendMessage(message: output.toString());

      final RegExp jsonRegex = RegExp(r'\[[\s\S]*\]');
      final Match? match = jsonRegex.firstMatch(result);
      final List<AIQueryResult> aiQueryResults = [];

      if (match != null) {
        try {
          final String jsonStr = match.group(0)!;
          final List<dynamic> resultList = jsonDecode(jsonStr) as List<dynamic>;

          for (final item in resultList) {
            if (item is Map<String, dynamic>) {
              final queryResult = AIQueryResult.fromJson(item);
              aiQueryResults.add(queryResult);
              // Add to cache
              _cache[queryResult.description] = queryResult;
            }
          }

          // Save updated cache
          _saveCache();

          print(
              'Successfully extracted ${aiQueryResults.length} AI query results');
        } catch (e) {
          print('Error parsing JSON from AI response: $e');
        }
      } else {
        print('No JSON array found in the AI response');
      }

      // Combine cached and new results
      return allTransactions.map((t) {
        return _cache[t.cleanedDescription] ??
            AIQueryResult(
                accountCode: 'UNKNOWN',
                description: t.cleanedDescription,
                reasoning: 'Failed to get account code');
      }).toList();
    } else {
      throw Exception('No bank import data available to process.');
    }
  }

  void _buildAiQueryHeader(StringBuffer output) {
    try {
      // Check if the data directory exists, create it if not
      final dataDir = Directory('data');
      if (!dataDir.existsSync()) {
        output.writeln('Data directory does not exist. Creating it now...');
        dataDir.createSync();
        output.writeln('Created data directory.');
      }

      // Check for the INSTRUCTIONS.md file and print its contents if it exists
      final instructionsFile = File('INSTRUCTIONS.md');
      if (instructionsFile.existsSync()) {
        try {
          final instructionsContent = instructionsFile.readAsStringSync();
          output.writeln('\n=== INSTRUCTIONS ===');
          output.writeln(instructionsContent);
          output.writeln('=== END OF INSTRUCTIONS ===\n');
        } catch (e) {
          output.writeln('Error reading instructions file: $e');
        }
      } else {
        output.writeln('Instructions file not found: @INSTRUCTIONS.md');
      }

      // Use ChartOfAccountsService to get accounts
      final chartService = ChartOfAccountsService();
      if (chartService.loadAccounts()) {
        final accounts = chartService.getAllAccounts();

        // Add CSV header to output
        output.writeln('\nCode,Name,Type');

        // Add each account as CSV row to output, but only revenue and expense types
        for (final account in accounts) {
          output.writeln('${account.code},${account.name},${account.type}');
        }

        output.writeln('\n');
      } else {
        output
            .writeln('Failed to load accounts from chart of accounts service');
      }
    } catch (e) {
      output.writeln('Error processing accounts file: $e');
    }
  }
}

/// A class representing a transaction pending processing with its associated completer.
class _PendingTransaction {
  /// The transaction to be processed
  final RawFileRow transaction;

  /// The completer that will resolve the Future when processing is complete
  final Completer<AIQueryResult> completer;

  /// Creates a new pending transaction
  _PendingTransaction({
    required this.transaction,
    required this.completer,
  });
}

/// Gets account codes for a batch of transactions using the batch service.
///
/// This function provides a simplified interface to the batch service, allowing
/// callers to get account codes for transactions without directly interacting
/// with the batch service implementation.
///
/// @param transactions The list of transactions to process
/// @return A Future that resolves with the list of AIQueryResults
Future<List<AIQueryResult>> getBatchedAccountCodes(
    List<RawFileRow> transactions) async {
  final batchService = AccountCodeService();

  // Create a list of futures by submitting each transaction to the batch service
  final futures = transactions
      .map((transaction) => batchService.getAccountCode(transaction))
      .toList();

  // Wait for all futures to complete and return the results
  return Future.wait(futures);
}

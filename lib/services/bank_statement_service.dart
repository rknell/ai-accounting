import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/extensions.dart';
import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/bank_import_models.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:path/path.dart' as path;

/// Service responsible for loading and parsing bank statement files.
///
/// This service handles:
/// - Loading CSV files from the inputs directory
/// - Parsing CSV content into structured data
/// - Converting raw data into [BankImportFile] objects
class BankStatementService {
  /// The directory where bank statement files are stored
  final String inputDirectoryPath;

  /// Directory containing accounting configuration (e.g., filename mappings)
  final String configDirectoryPath;

  /// All rows from all bank statement files that have been processed
  final allFileRows = <RawFileRow>[];

  /// Mapping between descriptive filenames and chart-of-accounts bank codes
  final Map<String, String> _filenameAccountMappings;

  /// Creates a new instance of [BankStatementService].
  ///
  /// The [inputDirectoryPath] parameter specifies the directory where bank statement
  /// files are located. By default, it uses the 'inputs' directory in the project root.
  /// This path is used when scanning for CSV files to import.
  BankStatementService({
    this.inputDirectoryPath = 'inputs',
    String? configDirectoryPath,
  })  : configDirectoryPath = configDirectoryPath ??
            Platform.environment['AI_ACCOUNTING_CONFIG_DIR'] ??
            'config',
        _filenameAccountMappings = _loadFilenameMappings(
          configDirectoryPath ??
              Platform.environment['AI_ACCOUNTING_CONFIG_DIR'] ??
              'config',
        );

  /// Loads all bank statement files and converts them into [BankImportFile] objects
  List<BankImportFile> loadBankImportFiles() {
    final files = _loadFiles();
    final bankImportFiles = <BankImportFile>[];
    final chartOfAccounts = services.chartOfAccounts;

    for (final file in files) {
      // Skip non-CSV files
      if (!file.path.toLowerCase().endsWith('.csv')) {
        continue;
      }

      try {
        final parsedFile = _parseBankStatementFile(file, chartOfAccounts);
        if (parsedFile != null) {
          bankImportFiles.add(parsedFile);
        }
      } catch (e) {
        print('Error processing file ${path.basename(file.path)}: $e');
      }
    }
    return bankImportFiles;
  }

  /// Loads a single bank statement file, optionally forcing the bank account code
  BankImportFile? loadSingleBankImportFile(
    String filePath, {
    String? bankAccountCode,
  }) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('Bank statement file not found: $filePath');
    }
    if (!file.path.toLowerCase().endsWith('.csv')) {
      throw Exception('Bank statement must be a CSV file: $filePath');
    }

    final chartOfAccounts = services.chartOfAccounts;
    return _parseBankStatementFile(
      file,
      chartOfAccounts,
      overrideBankAccountCode: bankAccountCode,
    );
  }

  /// Loads all files from the input directory
  List<File> _loadFiles() {
    final files = <File>[];
    final inputDir = Directory(inputDirectoryPath);

    if (inputDir.existsSync()) {
      final entities = inputDir.listSync();

      for (final entity in entities) {
        if (entity is File) {
          files.add(entity);
        }
      }

      if (files.isEmpty) {
        print('No input files found in the inputs directory.');
      }
    } else {
      print('Input directory does not exist. Creating it now...');
      inputDir.createSync();
      print('Created inputs directory. Please add files and run again.');
    }
    return files;
  }

  /// Helper function to parse CSV lines properly, handling quoted fields
  List<String> _parseCSVLine(String line) {
    final List<String> result = [];
    bool inQuotes = false;
    StringBuffer field = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(field.toString());
        field = StringBuffer();
      } else {
        field.write(char);
      }
    }

    // Add the last field
    result.add(field.toString());

    return result;
  }

  /// Parses a bank statement CSV file into a [BankImportFile]
  BankImportFile? _parseBankStatementFile(
    File file,
    ChartOfAccountsService chartOfAccounts, {
    String? overrideBankAccountCode,
  }) {
    final lines = file.readAsLinesSync();
    if (lines.length <= 1) {
      return null;
    }

    final resolvedBankAccountCode = overrideBankAccountCode != null
        ? _validateExplicitBankAccountCode(
            overrideBankAccountCode, chartOfAccounts)
        : _resolveBankAccountCode(file, chartOfAccounts);

    final rawFileRows = <RawFileRow>[];

    // Start from index 1 to skip the header
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;

      final fields = _parseCSVLine(line);

      if (fields.length >= 5) {
        var newFileRow = RawFileRow(
            date: fields[0].parseAustralianDate(),
            description: fields[1],
            debit: fields[2],
            credit: fields[3],
            balance: double.parse(fields[4]),
            bankAccountCode: resolvedBankAccountCode);
        rawFileRows.add(newFileRow);
        allFileRows.add(newFileRow);
      }
    }

    // Sort the rawFileRows by ascending date order
    rawFileRows.sort((a, b) => a.date.compareTo(b.date));

    if (rawFileRows.isEmpty) {
      return null;
    }

    return BankImportFile(
      rows: rawFileRows,
      bankAccountCode: resolvedBankAccountCode,
    );
  }

  /// Counts the number of journal entries that match the given entry's key attributes
  ///
  /// This method identifies potential duplicate transactions by counting entries with
  /// identical amount, date, description, and bank account. It's used to detect
  /// duplicate imports or reconciliation issues.
  ///
  /// The method compares the following attributes:
  /// - Transaction amount
  /// - Transaction date (year, month, day)
  /// - Transaction description
  /// - Bank account code (either as debit or credit)
  ///
  /// @param entry The journal entry to check for duplicates
  /// @return The number of matching entries found
  /// @throws Exception if no matching entries are found, indicating a data integrity issue
  int countIdenticalEntries(GeneralJournal entry) {
    var amount = entry.amount;
    var date = entry.date;
    var description = entry.description;
    var bankAcct = entry.bankCode;

    // Get all raw file rows instead of journal entries
    final allFileRows =
        loadBankImportFiles().expand((file) => file.rawFileRows).toList();

    // Count entries that match the same amount, date, description, and bank account
    int count = 0;
    for (final row in allFileRows) {
      final rowAmount = row.debit.isNotEmpty
          ? double.tryParse(row.debit.replaceAll(',', '')) ?? 0.0
          : double.tryParse(row.credit.replaceAll(',', '')) ?? 0.0;

      if (rowAmount == amount &&
          row.date.year == date.year &&
          row.date.month == date.month &&
          row.date.day == date.day &&
          row.description == description &&
          row.bankAccountCode == bankAcct) {
        count++;
      }
    }

    // If count is 0, something is wrong - this should never happen
    if (count == 0) {
      throw Exception(
          'Critical error: No matching entries found for transaction "$description" on ${date.toString().substring(0, 10)} with amount $amount. This indicates a data integrity issue.');
    }

    return count;
  }

  /// Resolve the bank account code for a CSV file, supporting filename mappings
  String _resolveBankAccountCode(
    File file,
    ChartOfAccountsService chartOfAccounts,
  ) {
    final baseName = path.basenameWithoutExtension(file.path);

    final directAccount = chartOfAccounts.getAccount(baseName);
    if (directAccount != null && directAccount.type == AccountType.bank) {
      return directAccount.code;
    }

    final mappedAccountCode = _lookupMappedAccountCode(baseName);
    if (mappedAccountCode != null) {
      final mappedAccount = chartOfAccounts.getAccount(mappedAccountCode);
      if (mappedAccount == null || mappedAccount.type != AccountType.bank) {
        throw Exception(
            'Mapping for "$baseName" references invalid account "$mappedAccountCode". Please update ${path.join(configDirectoryPath, 'bank_account_mappings.json')}');
      }
      return mappedAccount.code;
    }

    throw _missingBankAccountException(
      baseName,
      chartOfAccounts,
      includeMappingHint: true,
    );
  }

  String _validateExplicitBankAccountCode(
    String bankAccountCode,
    ChartOfAccountsService chartOfAccounts,
  ) {
    final normalizedCode = bankAccountCode.padLeft(3, '0');
    final account = chartOfAccounts.getAccount(normalizedCode);
    if (account == null || account.type != AccountType.bank) {
      throw _missingBankAccountException(normalizedCode, chartOfAccounts);
    }
    return normalizedCode;
  }

  Exception _missingBankAccountException(
    String attemptedCode,
    ChartOfAccountsService chartOfAccounts, {
    bool includeMappingHint = false,
  }) {
    final bankAccounts = chartOfAccounts
        .getAccountsByType(AccountType.bank)
        .map((account) => '${account.code} - ${account.name}')
        .join('\n');

    final buffer = StringBuffer(
        'No bank account found with code "$attemptedCode". Available bank accounts:\n$bankAccounts');

    if (includeMappingHint) {
      buffer.writeln(
          '\nTo map descriptive filenames, add an entry to ${path.join(configDirectoryPath, 'bank_account_mappings.json')}');
    }

    return Exception(buffer.toString());
  }

  /// Look up an account code based on the normalized filename
  String? _lookupMappedAccountCode(String baseName) {
    if (_filenameAccountMappings.isEmpty) {
      return null;
    }
    final normalizedKey = _normalizeFilenameKey(baseName);
    return _filenameAccountMappings[normalizedKey];
  }

  /// Load filename mappings from config/bank_account_mappings.json
  static Map<String, String> _loadFilenameMappings(String configDir) {
    final file = File(path.join(configDir, 'bank_account_mappings.json'));
    if (!file.existsSync()) {
      return {};
    }

    try {
      final raw = file.readAsStringSync();
      if (raw.trim().isEmpty) {
        return {};
      }

      final decoded = jsonDecode(raw);
      final mappings = <String, String>{};

      if (decoded is Map<String, dynamic>) {
        decoded.forEach((key, value) {
          if (value is String) {
            final normalizedKey = _normalizeFilenameKey(key);
            if (normalizedKey.isNotEmpty) {
              mappings[normalizedKey] = value.trim();
            }
          }
        });
      } else if (decoded is List<dynamic>) {
        for (final entry in decoded) {
          if (entry is Map<String, dynamic>) {
            final filename = entry['filename'] as String?;
            final accountCode = entry['accountCode'] as String?;
            if (filename != null && accountCode != null) {
              final normalizedKey = _normalizeFilenameKey(filename);
              if (normalizedKey.isNotEmpty) {
                mappings[normalizedKey] = accountCode.trim();
              }
            }
          }
        }
      }

      return mappings;
    } catch (e) {
      print(
          'Error loading filename mappings from ${file.path}: $e. Falling back to direct filename matching.');
      return {};
    }
  }

  /// Normalize filenames for mapping keys (case-insensitive, alphanumeric only)
  static String _normalizeFilenameKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}

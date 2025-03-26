import 'dart:io';

import 'package:ai_accounting/extensions.dart';
import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/bank_import_models.dart';
import 'package:ai_accounting/models/general_journal.dart';
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

  /// All rows from all bank statement files that have been processed
  final allFileRows = <RawFileRow>[];

  /// Creates a new instance of [BankStatementService].
  ///
  /// The [inputDirectoryPath] parameter specifies the directory where bank statement
  /// files are located. By default, it uses the 'inputs' directory in the project root.
  /// This path is used when scanning for CSV files to import.
  BankStatementService({this.inputDirectoryPath = 'inputs'});

  /// Loads all bank statement files and converts them into [BankImportFile] objects
  List<BankImportFile> loadBankImportFiles() {
    final files = _loadFiles();
    final bankImportFiles = <BankImportFile>[];

    for (final file in files) {
      // Skip non-CSV files
      if (!file.path.toLowerCase().endsWith('.csv')) {
        continue;
      }
      
      try {
        final lines = file.readAsLinesSync();
        final bankAccountCode = path.basenameWithoutExtension(file.path);

        // Check if a bank account exists with the given code
        final chartOfAccounts = services.chartOfAccounts;
        final bankAccount = chartOfAccounts.getAccount(bankAccountCode);

        if (bankAccount == null || bankAccount.type != AccountType.bank) {
          // Get all bank accounts for the error message
          final bankAccounts = chartOfAccounts
              .getAccountsByType(AccountType.bank)
              .map((account) => '${account.code} - ${account.name}')
              .join('\n');

          throw Exception(
              'No bank account found with code "$bankAccountCode". Available bank accounts:\n$bankAccounts');
        }

        if (lines.length > 1) {
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
                  bankAccountCode: bankAccountCode);
              rawFileRows.add(newFileRow);
              allFileRows.add(newFileRow);
            }
          }

          // Sort the rawFileRows by ascending date order
          rawFileRows.sort((a, b) => a.date.compareTo(b.date));

          if (rawFileRows.isNotEmpty) {
            bankImportFiles.add(BankImportFile(
              rows: rawFileRows,
              bankAccountCode: bankAccountCode,
            ));
          }
        }
      } catch (e) {
        print('Error processing file ${path.basename(file.path)}: $e');
      }
    }
    return bankImportFiles;
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
}

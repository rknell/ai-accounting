import 'dart:io';

import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/reports/general_journal_report.dart';
import 'package:ai_accounting/reports/ledger_report.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:path/path.dart' as path;

// Define categorizedTransactions map (temporary until we move this to a proper service)
final Map<String, String> categorizedTransactions = {};

Future<void> main() async {
  final services = Services();
  final bankImportFiles = services.bankStatement.loadBankImportFiles();

  for (var file in bankImportFiles) {
    for (var transaction in file.rawFileRows) {
      await transaction.getAccountCode();
      print('${transaction.accountCode} - ${transaction.reason}');
      if (transaction.accountCode.isNotEmpty) {
        try {
          final journalEntry = GeneralJournal.fromRawFileRow(transaction);
          services.generalJournal.addEntry(journalEntry);
        } catch (e, s) {
          print('Error creating journal entry: $e');
          print('Stack trace: $s');
          print('Continuing with next transaction...');
        }
      }
    }
  }

  // Generate reports for previous financial quarter
  final now = DateTime.now();

  // Calculate the previous financial quarter
  // Financial quarters are: Q1 (Jan-Mar), Q2 (Apr-Jun), Q3 (Jul-Sep), Q4 (Oct-Dec)
  final currentMonth = now.month;
  final currentQuarter = ((currentMonth - 1) ~/ 3) + 1;
  final previousQuarter = currentQuarter > 1 ? currentQuarter - 1 : 4;

  // Determine the year for the previous quarter (previous year if we're in Q1)
  final quarterYear = currentQuarter > 1 ? now.year : now.year - 1;

  // Calculate the start and end of the previous financial quarter
  final quarterStartMonth = (previousQuarter - 1) * 3 + 1; // 1, 4, 7, or 10
  final quarterEndMonth = quarterStartMonth + 2; // 3, 6, 9, or 12

  // Start at beginning of first day (00:00:00)
  final quarterStart = DateTime(quarterYear, quarterStartMonth, 1);

  // End at end of last day (23:59:59)
  final quarterEnd = DateTime(quarterYear, quarterEndMonth + 1, 1)
      .subtract(const Duration(days: 1))
      .copyWith(
          hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);

  // Generate profit and loss report
  services.reports.generateProfitAndLossReport(quarterStart, quarterEnd);

  // Generate balance sheet (as of end of quarter)
  services.reports.generateBalanceSheet(quarterEnd);

  // Generate GST report
  services.reports.generateGSTReport(quarterStart, quarterEnd);

  final report = GeneralJournalReport(services);
  report.generate(quarterStart, quarterEnd);

  LedgerReport(services).generate(quarterStart, quarterEnd);

  // Generate report wrapper for easy navigation
  services.reports.generateReportWrapper();

  print(
      '\nReports generated for previous financial quarter: ${quarterStart.toString().substring(0, 10)} to ${quarterEnd.toString().substring(0, 10)}');
  print('Check the data/ directory for the generated HTML reports.');
  print(
      'Open data/report_viewer.html to view all reports in a navigable interface.');

  // Copy input files to data directory for backup
  final inputsDirectory = Directory(services.bankStatement.inputDirectoryPath);
  final backupDirectory = Directory('data/backup_inputs');

  // Create backup directory if it doesn't exist
  if (!backupDirectory.existsSync()) {
    backupDirectory.createSync(recursive: true);
    print('Created backup directory: ${backupDirectory.path}');
  }

  // Get current date for backup folder name
  final backupDate = DateTime.now().toString().substring(0, 10);
  final dateBackupDir = Directory('${backupDirectory.path}/$backupDate');

  // Create date-specific backup directory if it doesn't exist
  if (!dateBackupDir.existsSync()) {
    dateBackupDir.createSync();
  }

  // Copy all files from inputs directory to the backup directory
  if (inputsDirectory.existsSync()) {
    int filesCopied = 0;
    for (final entity in inputsDirectory.listSync()) {
      if (entity is File) {
        final fileName = path.basename(entity.path);
        final destinationPath = '${dateBackupDir.path}/$fileName';

        // Copy the file
        entity.copySync(destinationPath);
        filesCopied++;
      }
    }

    if (filesCopied > 0) {
      print('\nBacked up $filesCopied input files to ${dateBackupDir.path}');
    } else {
      print('\nNo input files found to back up.');
    }
  } else {
    print('\nInputs directory does not exist. No files to back up.');
  }

  exit(0);

  // categorise them
  // create a profit and loss (last qtr, FYTD, LFY)
  // create a balance sheet (Today, End of last qtr, Start of FY)
  // create a GST report (last qtr)
  // backup to google drive with transactions
}

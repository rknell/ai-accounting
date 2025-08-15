import 'dart:io';

import 'package:ai_accounting/reports/general_journal_report.dart';
import 'package:ai_accounting/reports/ledger_report.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:path/path.dart' as path;

/// Service for generating financial reports for a specific period
class ReportGenerationService {
  /// The services instance for accessing other application services
  final Services services;

  /// Creates a new ReportGenerationService with the provided services
  ReportGenerationService(this.services);

  /// Generates all financial reports for the previous financial quarter
  ///
  /// This includes:
  /// - Profit and Loss Report
  /// - Balance Sheet
  /// - GST Report
  /// - General Journal Report
  /// - Ledger Report
  /// - Report Wrapper for navigation
  ///
  /// Reports are generated for the previous financial quarter based on current date.
  /// Financial quarters are: Q1 (Jan-Mar), Q2 (Apr-Jun), Q3 (Jul-Sep), Q4 (Oct-Dec)
  void generateReports() {
    print('📊 Generating financial reports...');

    final reportPeriod = _calculatePreviousQuarter();
    final quarterStart = reportPeriod['start'] as DateTime;
    final quarterEnd = reportPeriod['end'] as DateTime;

    print(
        'Report period: ${quarterStart.toString().substring(0, 10)} to ${quarterEnd.toString().substring(0, 10)}');

    // Generate profit and loss report
    services.reports.generateProfitAndLossReport(quarterStart, quarterEnd);

    // Generate balance sheet (as of end of quarter)
    services.reports.generateBalanceSheet(quarterEnd);

    // Generate GST report
    services.reports.generateGSTReport(quarterStart, quarterEnd);

    // Generate general journal report
    final journalReport = GeneralJournalReport(services);
    journalReport.generate(quarterStart, quarterEnd);

    // Generate ledger report
    LedgerReport(services).generate(quarterStart, quarterEnd);

    // Generate report wrapper for easy navigation
    services.reports.generateReportWrapper();

    // Backup input files
    _backupInputFiles();

    print('\n✅ Reports generated successfully!');
    print('📁 Check the data/ directory for the generated HTML reports.');
    print(
        '🌐 Open data/report_viewer.html to view all reports in a navigable interface.');
  }

  /// Calculates the start and end dates for the previous financial quarter
  ///
  /// Returns a map with 'start' and 'end' DateTime objects representing
  /// the previous financial quarter period.
  Map<String, DateTime> _calculatePreviousQuarter() {
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
            hour: 23,
            minute: 59,
            second: 59,
            millisecond: 999,
            microsecond: 999);

    return {
      'start': quarterStart,
      'end': quarterEnd,
    };
  }

  /// Backs up input files to the data/backup_inputs directory with date stamp
  void _backupInputFiles() {
    final projectRoot = Directory.current.path;
    final dataDir = Directory(path.join(projectRoot, 'data'));
    final inputsDir = Directory(path.join(projectRoot, 'inputs'));

    final backupDirectory = Directory(path.join(dataDir.path, 'backup_inputs'));

    // Create backup directory if it doesn't exist
    if (!backupDirectory.existsSync()) {
      backupDirectory.createSync(recursive: true);
      print('📁 Created backup directory: ${backupDirectory.path}');
    }

    // Get current date for backup folder name
    final backupDate = DateTime.now().toString().substring(0, 10);
    final dateBackupDir =
        Directory(path.join(backupDirectory.path, backupDate));

    // Create date-specific backup directory if it doesn't exist
    if (!dateBackupDir.existsSync()) {
      dateBackupDir.createSync();
    }

    // Copy all files from inputs directory to the backup directory
    if (inputsDir.existsSync()) {
      int filesCopied = 0;
      for (final entity in inputsDir.listSync()) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          final destinationPath = path.join(dateBackupDir.path, fileName);

          // Copy the file
          entity.copySync(destinationPath);
          filesCopied++;
        }
      }

      if (filesCopied > 0) {
        print('💾 Backed up $filesCopied input files to ${dateBackupDir.path}');
      } else {
        print('⚠️  No input files found to back up.');
      }
    } else {
      print('⚠️  Inputs directory does not exist. No files to back up.');
    }
  }
}

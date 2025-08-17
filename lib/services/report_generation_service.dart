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

  /// Generates financial reports for the previous quarter only
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
  void generatePreviousQuarterReports() {
    print('📊 Generating financial reports for previous quarter...');

    final reportPeriod = _calculatePreviousQuarter();
    final quarterStart = reportPeriod['start'] as DateTime;
    final quarterEnd = reportPeriod['end'] as DateTime;

    print(
        'Report period: ${quarterStart.toString().substring(0, 10)} to ${quarterEnd.toString().substring(0, 10)}');

    // Check if there's any data for this quarter
    final quarterEntries =
        services.generalJournal.getEntriesByDateRange(quarterStart, quarterEnd);
    if (quarterEntries.isEmpty) {
      print('⚠️  No transaction data found for the previous quarter.');
      return;
    }

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

    print('\n✅ Previous quarter reports generated successfully!');
    print('📁 Check the data/ directory for the generated HTML reports.');
    print(
        '🌐 Open data/report_viewer.html to view all reports in a navigable interface.');
  }

  /// Generates all financial reports for all quarters that have transaction data
  ///
  /// This includes:
  /// - Profit and Loss Report
  /// - Balance Sheet
  /// - GST Report
  /// - General Journal Report
  /// - Ledger Report
  /// - Report Wrapper for navigation
  ///
  /// Reports are generated for all quarters that contain financial transactions.
  /// Financial quarters are: Q1 (Jan-Mar), Q2 (Apr-Jun), Q3 (Jul-Sep), Q4 (Oct-Dec)
  void generateReports() {
    print('📊 Generating financial reports for all quarters with data...');

    final quartersWithData = _findQuartersWithData();

    if (quartersWithData.isEmpty) {
      print('⚠️  No transaction data found. No reports to generate.');
      return;
    }

    print('Found data for ${quartersWithData.length} quarters:');
    for (final quarter in quartersWithData) {
      final start = quarter['start'] as DateTime;
      final end = quarter['end'] as DateTime;
      print(
          '  - ${start.toString().substring(0, 10)} to ${end.toString().substring(0, 10)}');
    }

    // Generate reports for each quarter with data
    for (final quarter in quartersWithData) {
      final quarterStart = quarter['start'] as DateTime;
      final quarterEnd = quarter['end'] as DateTime;

      print(
          '\n📈 Generating reports for quarter: ${quarterStart.toString().substring(0, 10)} to ${quarterEnd.toString().substring(0, 10)}');

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
    }

    // Generate report wrapper for easy navigation
    services.reports.generateReportWrapper();

    // Backup input files
    _backupInputFiles();

    print(
        '\n✅ Reports generated successfully for all ${quartersWithData.length} quarters!');
    print('📁 Check the data/ directory for the generated HTML reports.');
    print(
        '🌐 Open data/report_viewer.html to view all reports in a navigable interface.');
  }

  /// Finds all quarters that contain transaction data
  ///
  /// Returns a list of maps with 'start' and 'end' DateTime objects representing
  /// each quarter that contains financial transactions, sorted chronologically.
  List<Map<String, DateTime>> _findQuartersWithData() {
    final allEntries = services.generalJournal.getAllEntries();

    if (allEntries.isEmpty) {
      return [];
    }

    // Find the earliest and latest transaction dates
    final sortedEntries = List<DateTime>.from(allEntries.map((e) => e.date))
      ..sort();

    final earliestDate = sortedEntries.first;
    final latestDate = sortedEntries.last;

    // Generate all quarters between earliest and latest dates
    final quarters = <Map<String, DateTime>>[];

    var currentYear = earliestDate.year;
    var currentQuarter = ((earliestDate.month - 1) ~/ 3) + 1;

    while (true) {
      final quarterDates = _getQuarterDates(currentYear, currentQuarter);
      final quarterStart = quarterDates['start']!;
      final quarterEnd = quarterDates['end']!;

      // Check if this quarter has any transactions
      final quarterEntries = services.generalJournal
          .getEntriesByDateRange(quarterStart, quarterEnd);

      if (quarterEntries.isNotEmpty) {
        quarters.add(quarterDates);
      }

      // Move to next quarter
      currentQuarter++;
      if (currentQuarter > 4) {
        currentQuarter = 1;
        currentYear++;
      }

      // Stop if we've passed the latest transaction date
      if (quarterStart.isAfter(latestDate)) {
        break;
      }
    }

    return quarters;
  }

  /// Gets the start and end dates for a specific quarter and year
  ///
  /// Returns a map with 'start' and 'end' DateTime objects representing
  /// the specified quarter period.
  Map<String, DateTime> _getQuarterDates(int year, int quarter) {
    final quarterStartMonth = (quarter - 1) * 3 + 1; // 1, 4, 7, or 10
    final quarterEndMonth = quarterStartMonth + 2; // 3, 6, 9, or 12

    // Start at beginning of first day (00:00:00)
    final quarterStart = DateTime(year, quarterStartMonth, 1);

    // End at end of last day (23:59:59)
    final quarterEnd = DateTime(year, quarterEndMonth + 1, 1)
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

    return _getQuarterDates(quarterYear, previousQuarter);
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

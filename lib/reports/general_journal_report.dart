import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/reports/base_report.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';

/// Report that generates a general journal report
class GeneralJournalReport extends BaseReport {
  /// Creates a new general journal report generator
  ///
  /// @param services The services instance containing required services
  GeneralJournalReport(super.services);

  /// Generates a general journal report for a specified date range
  ///
  /// @param startDate The start date of the report period
  /// @param endDate The end date of the report period
  /// @return True if the report was successfully generated, false otherwise
  bool generate(DateTime startDate, DateTime endDate) {
    try {
      final generalJournalService = services.generalJournal;
      final chartOfAccounts = services.chartOfAccounts;

      // Get all entries within the date range
      final entries = generalJournalService.entries
          .where((entry) =>
              entry.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              entry.date.isBefore(endDate.add(const Duration(days: 1))))
          .toList();

      // Sort entries by date
      entries.sort((a, b) => a.date.compareTo(b.date));

      // Generate HTML report
      final html = _generateHtml(startDate, endDate, entries, chartOfAccounts);

      // Save the report to file
      final fileName =
          'general_journal_${formatDateForFileName(startDate)}_to_${formatDateForFileName(endDate)}.html';
      return saveReport(html, fileName);
    } catch (e) {
      print('Error generating General Journal report: $e');
      return false;
    }
  }

  /// Generates the HTML content for the general journal report
  String _generateHtml(DateTime startDate, DateTime endDate,
      List<GeneralJournal> entries, ChartOfAccountsService chartOfAccounts) {
    final buffer = StringBuffer();

    buffer.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>General Journal</title>
    <style>
$commonStyles
        .journal-entry {
            border-bottom: 1px solid #eee;
            padding: 10px 0;
        }
        .entry-date {
            font-weight: bold;
            color: #333;
        }
        .entry-description {
            color: #666;
            font-style: italic;
            margin: 5px 0;
        }
        .entry-line {
            display: grid;
            grid-template-columns: 30px minmax(200px, 1fr) 120px 120px;
            align-items: center;
            padding: 3px 0;
        }
        .entry-line.credit {
            padding-left: 30px;
        }
        .account-code {
            color: #666;
            font-size: 0.9em;
        }
    </style>
$commonScripts
</head>
<body>
    <div class="report-header">
        <h1>General Journal</h1>
        <div class="report-date">
            For the period ${formatDateForDisplay(startDate)} to ${formatDateForDisplay(endDate)}
        </div>
    </div>
    
    <div class="section">
        <div class="section-title">Journal Entries</div>
        <div class="journal-entries">
''');

    // Generate entries
    for (final entry in entries) {
      buffer.writeln('''
            <div class="journal-entry">
                <div class="entry-date">${formatDateForDisplay(entry.date)}</div>
                <div class="entry-description">${entry.description}</div>
''');

      // Write debit entries
      for (final debit in entry.debits) {
        final account = chartOfAccounts.getAccount(debit.accountCode);
        buffer.writeln('''
                <div class="entry-line">
                    <span></span>
                    <span>${account?.code ?? ''} - ${account?.name ?? 'Unknown Account'}</span>
                    <span class="amount">${formatCurrency(debit.amount)}</span>
                    <span></span>
                </div>
''');
      }

      // Write credit entries
      for (final credit in entry.credits) {
        final account = chartOfAccounts.getAccount(credit.accountCode);
        buffer.writeln('''
                <div class="entry-line credit">
                    <span></span>
                    <span>${account?.code ?? ''} - ${account?.name ?? 'Unknown Account'}</span>
                    <span></span>
                    <span class="amount">${formatCurrency(credit.amount)}</span>
                </div>
''');
      }

      buffer.writeln('            </div>');
    }

    buffer.writeln('''
        </div>
    </div>
</body>
</html>
''');

    return buffer.toString();
  }
}

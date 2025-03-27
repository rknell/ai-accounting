import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/reports/base_report.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';

/// Report that generates a GST (Goods and Services Tax) report
class GSTReport extends BaseReport {
  /// Creates a new GST report generator
  ///
  /// @param services The services instance containing required services
  GSTReport(super.services);

  /// Generates a GST report for a specified date range
  ///
  /// @param startDate The start date of the report period
  /// @param endDate The end date of the report period
  /// @return True if the report was successfully generated, false otherwise
  bool generate(DateTime startDate, DateTime endDate) {
    try {
      final generalJournalService = services.generalJournal;
      final chartOfAccounts = services.chartOfAccounts;
      final environment = services.environment;

      // Get all GST applicable income and expense accounts
      final incomeAccounts = chartOfAccounts
          .getAccountsByType(AccountType.revenue)
          .where((account) =>
              account.gst && account.gstType == GstType.gstOnIncome)
          .toList();

      final expenseAccounts = chartOfAccounts
          .getAccountsByType(AccountType.expense)
          .where((account) =>
              account.gst && account.gstType == GstType.gstOnExpenses)
          .toList();

      // Get the GST clearing account
      final gstAccount =
          chartOfAccounts.getAccount(environment.gstClearingAccountCode);

      // Calculate totals for each account within the date range
      final incomeTotals = <String, double>{};
      final expenseTotals = <String, double>{};
      double totalGstExclusiveIncome = 0;
      double totalGstExclusiveExpenses = 0;

      // Process income accounts
      for (final account in incomeAccounts) {
        final entries = generalJournalService.getEntriesByAccount(account.code);
        final filteredEntries = entries
            .where((entry) =>
                entry.date
                    .isAfter(startDate.subtract(const Duration(days: 1))) &&
                entry.date.isBefore(endDate.add(const Duration(days: 1))))
            .toList();

        double accountTotal = 0;
        for (final entry in filteredEntries) {
          // For income accounts, credit increases (positive) and debit decreases (negative)
          accountTotal += getTransactionAmountForAccount(entry, account.code,
              isPositive: true);
        }

        if (accountTotal != 0) {
          incomeTotals[account.code] = accountTotal;
          totalGstExclusiveIncome += accountTotal;
        }
      }

      // Process expense accounts
      for (final account in expenseAccounts) {
        final entries = generalJournalService.getEntriesByAccount(account.code);
        final filteredEntries = entries
            .where((entry) =>
                entry.date
                    .isAfter(startDate.subtract(const Duration(days: 1))) &&
                entry.date.isBefore(endDate.add(const Duration(days: 1))))
            .toList();

        double accountTotal = 0;
        for (final entry in filteredEntries) {
          // For expense accounts, debit increases (positive) and credit decreases (negative)
          accountTotal += getTransactionAmountForAccount(entry, account.code,
              isPositive: false);
        }

        if (accountTotal != 0) {
          expenseTotals[account.code] = accountTotal;
          totalGstExclusiveExpenses += accountTotal;
        }
      }

      // Calculate GST components directly from the GST clearing account
      double gstOnSales = 0.0;
      double gstOnExpenses = 0.0;

      if (gstAccount != null) {
        final gstEntries = generalJournalService
            .getEntriesByAccount(gstAccount.code)
            .where((entry) =>
                entry.date
                    .isAfter(startDate.subtract(const Duration(days: 1))) &&
                entry.date.isBefore(endDate.add(const Duration(days: 1))))
            .toList();

        for (final entry in gstEntries) {
          // Calculate credit amount (GST collected on sales)
          for (final credit in entry.credits) {
            if (credit.accountCode == gstAccount.code) {
              gstOnSales += credit.amount;
            }
          }

          // Calculate debit amount (GST paid on purchases)
          for (final debit in entry.debits) {
            if (debit.accountCode == gstAccount.code) {
              gstOnExpenses += debit.amount;
            }
          }
        }
      } else {
        // If GST account is not found, log an error - GST calculations will be incorrect
        print(
            'Warning: GST clearing account not found. GST calculations may be inaccurate.');
        gstOnSales = 0;
        gstOnExpenses = 0;
      }

      // Calculate net GST
      final netGST = gstOnSales - gstOnExpenses;

      // Generate HTML report
      final html = _generateHtml(
          startDate,
          endDate,
          incomeTotals,
          expenseTotals,
          totalGstExclusiveIncome,
          totalGstExclusiveExpenses,
          gstOnSales,
          gstOnExpenses,
          netGST,
          chartOfAccounts);

      // Save the report to file
      final fileName =
          'gst_report_${formatDateForFileName(startDate)}_to_${formatDateForFileName(endDate)}.html';
      return saveReport(html, fileName);
    } catch (e) {
      print('Error generating GST report: $e');
      return false;
    }
  }

  /// Generates the HTML content for the GST report
  String _generateHtml(
      DateTime startDate,
      DateTime endDate,
      Map<String, double> incomeTotals,
      Map<String, double> expenseTotals,
      double totalGstExclusiveIncome,
      double totalGstExclusiveExpenses,
      double gstOnSales,
      double gstOnExpenses,
      double netGST,
      ChartOfAccountsService chartOfAccounts) {
    final buffer = StringBuffer();

    buffer.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GST Report</title>
    <style>
$commonStyles
    </style>
$commonScripts
</head>
<body>
    <div class="report-header">
        <h1>GST Report</h1>
        <div class="report-date">
            For the period ${formatDateForDisplay(startDate)} to ${formatDateForDisplay(endDate)}
        </div>
    </div>
    
    <div class="section">
        <div class="section-title">GST Applicable Sales (GST Exclusive)</div>
        <table>
            <thead>
                <tr>
                    <th>Account</th>
                    <th class="amount-column">Amount</th>
                </tr>
            </thead>
            <tbody>
                ${_generateIncomeRows(incomeTotals, chartOfAccounts, startDate, endDate)}
                <tr class="total-row">
                    <td>Total GST Exclusive Sales:</td>
                    <td class="amount positive key-figure">${formatCurrency(totalGstExclusiveIncome)}</td>
                </tr>
                <tr class="item-group">
                    <td>GST Collected:</td>
                    <td class="amount positive">${formatCurrency(gstOnSales)}</td>
                </tr>
                <tr class="item-group">
                    <td>Total GST Inclusive Sales:</td>
                    <td class="amount positive key-figure">${formatCurrency(totalGstExclusiveIncome + gstOnSales)}</td>
                </tr>
            </tbody>
        </table>
    </div>

    <div class="section">
        <div class="section-title">GST Applicable Expenses (GST Exclusive)</div>
        <table>
            <thead>
                <tr>
                    <th>Account</th>
                    <th class="amount-column">Amount</th>
                </tr>
            </thead>
            <tbody>
                ${_generateExpenseRows(expenseTotals, chartOfAccounts, startDate, endDate)}
                <tr class="total-row">
                    <td>Total GST Exclusive Expenses:</td>
                    <td class="amount negative key-figure">${formatCurrency(totalGstExclusiveExpenses)}</td>
                </tr>
                <tr class="item-group">
                    <td>GST Paid:</td>
                    <td class="amount negative">${formatCurrency(gstOnExpenses)}</td>
                </tr>
                <tr class="item-group">
                    <td>Total GST Inclusive Expenses:</td>
                    <td class="amount negative key-figure">${formatCurrency(totalGstExclusiveExpenses + gstOnExpenses)}</td>
                </tr>
            </tbody>
        </table>
    </div>
    
    <div class="summary">
        <div class="summary-title">GST Summary</div>
        <table>
            <tbody>
                <tr class="item-group">
                    <td>GST Exclusive Sales:</td>
                    <td class="amount positive">${formatCurrency(totalGstExclusiveIncome)}</td>
                </tr>
                <tr>
                    <td>GST Collected on Sales:</td>
                    <td class="amount positive">${formatCurrency(gstOnSales)}</td>
                </tr>
                <!-- DO NOT PUT THE GST EXCLUSIVE EXPENSES HERE, WE ARE KEEPING THE SAME FORMAT AS THE ATO -->
                <tr>
                    <td>GST Paid on Expenses:</td>
                    <td class="amount negative">${formatCurrency(gstOnExpenses)}</td>
                </tr>
                <tr class="net-item ${netGST > 0 ? 'payable' : 'refund'}">
                    <td>Net GST ${netGST > 0 ? 'Payable' : 'Refund'}:</td>
                    <td class="amount key-figure">${formatCurrency(netGST.abs())}</td>
                </tr>
            </tbody>
        </table>
    </div>

    $commonTransactionPanel
</body>
</html>
''');

    return buffer.toString();
  }

  /// Generates HTML rows for income accounts
  String _generateIncomeRows(
      Map<String, double> incomeTotals,
      ChartOfAccountsService chartOfAccounts,
      DateTime startDate,
      DateTime endDate) {
    final buffer = StringBuffer();
    for (final entry in incomeTotals.entries) {
      final account = chartOfAccounts.getAccount(entry.key);
      if (account != null) {
        // Get transaction count for this account
        final transactions =
            getTransactionsForAccount(account.code, startDate, endDate);

        buffer.write(generateAccountRow(
            account, entry.value, startDate, endDate,
            isPositive: true, transactionCount: transactions.length));
      }
    }
    return buffer.toString();
  }

  /// Generates HTML rows for expense accounts
  String _generateExpenseRows(
      Map<String, double> expenseTotals,
      ChartOfAccountsService chartOfAccounts,
      DateTime startDate,
      DateTime endDate) {
    final buffer = StringBuffer();
    for (final entry in expenseTotals.entries) {
      final account = chartOfAccounts.getAccount(entry.key);
      if (account != null) {
        // Get transaction count for this account
        final transactions =
            getTransactionsForAccount(account.code, startDate, endDate);

        buffer.write(generateAccountRow(
            account, entry.value, startDate, endDate,
            isPositive: false, transactionCount: transactions.length));
      }
    }
    return buffer.toString();
  }
}

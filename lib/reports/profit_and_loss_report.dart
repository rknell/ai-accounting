import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/reports/base_report.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';

/// Report that generates a profit and loss statement
class ProfitAndLossReport extends BaseReport {
  /// Creates a new profit and loss report generator
  ///
  /// @param services The services instance containing required services
  ProfitAndLossReport(super.services);

  /// Generates a profit and loss report for a specified date range
  ///
  /// @param startDate The start date of the report period
  /// @param endDate The end date of the report period
  /// @return True if the report was successfully generated, false otherwise
  bool generate(DateTime startDate, DateTime endDate) {
    try {
      final generalJournalService = services.generalJournal;
      final chartOfAccounts = services.chartOfAccounts;

      // Get all income and expense accounts
      final incomeAccounts =
          chartOfAccounts.getAccountsByType(AccountType.revenue);
      final cogsAccounts = chartOfAccounts.getAccountsByType(AccountType.cogs);
      final expenseAccounts =
          chartOfAccounts.getAccountsByType(AccountType.expense);

      // Calculate totals for each account within the date range
      final revenueTotals = <String, double>{};
      final cogsTotals = <String, double>{};
      final expenseTotals = <String, double>{};
      double totalRevenue = 0;
      double totalCogs = 0;
      double totalExpenses = 0;

      // Track transaction counts
      final revenueTransactionCounts = <String, int>{};
      final cogsTransactionCounts = <String, int>{};
      final expenseTransactionCounts = <String, int>{};
      int totalIncomeTransactions = 0;
      int totalCogsTransactions = 0;
      int totalExpenseTransactions = 0;

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
        int transactionCount = filteredEntries.length;

        for (final entry in filteredEntries) {
          // For revenue accounts, credit increases (positive) and debit decreases (negative)
          accountTotal += getTransactionAmountForAccount(entry, account.code,
              isPositive: true);
        }

        if (accountTotal != 0) {
          revenueTotals[account.code] = accountTotal;
          revenueTransactionCounts[account.code] = transactionCount;
          totalRevenue += accountTotal;
          totalIncomeTransactions += transactionCount;
        }
      }

      // Process COGS accounts
      for (final account in cogsAccounts) {
        final entries = generalJournalService.getEntriesByAccount(account.code);
        final filteredEntries = entries
            .where((entry) =>
                entry.date
                    .isAfter(startDate.subtract(const Duration(days: 1))) &&
                entry.date.isBefore(endDate.add(const Duration(days: 1))))
            .toList();

        double accountTotal = 0;
        int transactionCount = filteredEntries.length;

        for (final entry in filteredEntries) {
          // For COGS accounts, debit increases (positive) and credit decreases (negative)
          accountTotal += getTransactionAmountForAccount(entry, account.code,
              isPositive: false);
        }

        if (accountTotal != 0) {
          cogsTotals[account.code] = accountTotal;
          cogsTransactionCounts[account.code] = transactionCount;
          totalCogs += accountTotal;
          totalCogsTransactions += transactionCount;
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
        int transactionCount = filteredEntries.length;

        for (final entry in filteredEntries) {
          // For expense accounts, debit increases (positive) and credit decreases (negative)
          accountTotal += getTransactionAmountForAccount(entry, account.code,
              isPositive: false);
        }

        if (accountTotal != 0) {
          expenseTotals[account.code] = accountTotal;
          expenseTransactionCounts[account.code] = transactionCount;
          totalExpenses += accountTotal;
          totalExpenseTransactions += transactionCount;
        }
      }

      // Calculate gross profit and net profit
      final grossProfit = totalRevenue - totalCogs;
      final netProfit = grossProfit - totalExpenses;

      // Generate HTML report
      final html = _generateHtml(
          startDate,
          endDate,
          revenueTotals,
          cogsTotals,
          expenseTotals,
          totalRevenue,
          totalCogs,
          totalExpenses,
          grossProfit,
          netProfit,
          chartOfAccounts,
          revenueTransactionCounts,
          cogsTransactionCounts,
          expenseTransactionCounts,
          totalIncomeTransactions,
          totalCogsTransactions,
          totalExpenseTransactions);

      // Save the report to file
      final fileName =
          'profit_loss_${formatDateForFileName(startDate)}_to_${formatDateForFileName(endDate)}.html';
      return saveReport(html, fileName);
    } catch (e) {
      print('Error generating Profit and Loss report: $e');
      return false;
    }
  }

  /// Generates the HTML content for the profit and loss report
  String _generateHtml(
      DateTime startDate,
      DateTime endDate,
      Map<String, double> incomeTotals,
      Map<String, double> cogsTotals,
      Map<String, double> expenseTotals,
      double totalIncome,
      double totalCogs,
      double totalExpenses,
      double grossProfit,
      double netProfit,
      ChartOfAccountsService chartOfAccounts,
      Map<String, int> incomeTransactionCounts,
      Map<String, int> cogsTransactionCounts,
      Map<String, int> expenseTransactionCounts,
      int totalIncomeTransactions,
      int totalCogsTransactions,
      int totalExpenseTransactions) {
    final buffer = StringBuffer();

    buffer.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Profit and Loss Statement</title>
    <style>
$commonStyles
    </style>
$commonScripts
</head>
<body>
    <div class="report-header">
        <h1>Profit and Loss Statement</h1>
        <div class="report-date">
            For the period ${formatDateForDisplay(startDate)} to ${formatDateForDisplay(endDate)}
        </div>
    </div>
    
    <div class="section">
        <div class="section-title">Income</div>
        <table>
            <thead>
                <tr>
                    <th>Account</th>
                    <th class="amount-column">Amount</th>
                </tr>
            </thead>
            <tbody>
                ${_generateAccountRows(incomeTotals, chartOfAccounts, startDate, endDate, incomeTransactionCounts)}
                <tr class="total-row">
                    <td>Total Income</td>
                    <td class="amount positive key-figure">${formatCurrency(totalIncome)}</td>
                </tr>
            </tbody>
        </table>
    </div>

    <div class="section">
        <div class="section-title">Less Cost of Goods Sold</div>
        <table>
            <thead>
                <tr>
                    <th>Account</th>
                    <th class="amount-column">Amount</th>
                </tr>
            </thead>
            <tbody>
                ${_generateAccountRows(cogsTotals, chartOfAccounts, startDate, endDate, cogsTransactionCounts)}
                <tr class="total-row">
                    <td>Total COGS</td>
                    <td class="amount negative key-figure">${formatCurrency(totalCogs)}</td>
                </tr>
            </tbody>
        </table>
    </div>

    <div class="summary">
        <div class="summary-title">Gross Profit</div>
        <table>
            <tbody>
                <tr class="item-group">
                    <td>Total Revenue</td>
                    <td class="amount positive">${formatCurrency(totalIncome)}</td>
                </tr>
                <tr class="item-group">
                    <td>Total COGS</td>
                    <td class="amount negative">${formatCurrency(totalCogs)}</td>
                </tr>
                <tr class="net-item">
                    <td>Gross Profit</td>
                    <td class="amount ${grossProfit >= 0 ? 'positive' : 'negative'} key-figure">${formatCurrency(grossProfit)}</td>
                </tr>
            </tbody>
        </table>
    </div>

    <div class="section">
        <div class="section-title">Operating Expenses</div>
        <table>
            <thead>
                <tr>
                    <th>Account</th>
                    <th class="amount-column">Amount</th>
                </tr>
            </thead>
            <tbody>
                ${_generateAccountRows(expenseTotals, chartOfAccounts, startDate, endDate, expenseTransactionCounts)}
                <tr class="total-row">
                    <td>Total Expenses</td>
                    <td class="amount negative key-figure">${formatCurrency(totalExpenses)}</td>
                </tr>
            </tbody>
        </table>
    </div>

    <div class="summary">
        <div class="summary-title">Net Profit</div>
        <table>
            <tbody>
                <tr class="item-group">
                    <td>Gross Profit</td>
                    <td class="amount ${grossProfit >= 0 ? 'positive' : 'negative'}">${formatCurrency(grossProfit)}</td>
                </tr>
                <tr class="item-group">
                    <td>Total Expenses</td>
                    <td class="amount negative">${formatCurrency(totalExpenses)}</td>
                </tr>
                <tr class="net-item">
                    <td>Net Profit</td>
                    <td class="amount ${netProfit >= 0 ? 'positive' : 'negative'} key-figure">${formatCurrency(netProfit)}</td>
                </tr>
            </tbody>
        </table>
    </div>

    <div class="section">
        <div class="section-title">Transaction Summary</div>
        <table>
            <tbody>
                <tr>
                    <td>Total Income Transactions</td>
                    <td class="amount">$totalIncomeTransactions</td>
                </tr>
                <tr>
                    <td>Total COGS Transactions</td>
                    <td class="amount">$totalCogsTransactions</td>
                </tr>
                <tr>
                    <td>Total Expense Transactions</td>
                    <td class="amount">$totalExpenseTransactions</td>
                </tr>
                <tr class="total-row">
                    <td>Grand Total Transactions</td>
                    <td class="amount">${totalIncomeTransactions + totalCogsTransactions + totalExpenseTransactions}</td>
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

  /// Generates HTML rows for account balances
  String _generateAccountRows(
      Map<String, double> accountTotals,
      ChartOfAccountsService chartOfAccounts,
      DateTime startDate,
      DateTime endDate,
      Map<String, int> transactionCounts) {
    final buffer = StringBuffer();
    for (final entry in accountTotals.entries) {
      final account = chartOfAccounts.getAccount(entry.key);
      if (account != null) {
        buffer.write(generateAccountRow(
            account, entry.value, startDate, endDate,
            isPositive: entry.value >= 0,
            transactionCount: transactionCounts[entry.key] ?? 0));
      }
    }
    return buffer.toString();
  }
}

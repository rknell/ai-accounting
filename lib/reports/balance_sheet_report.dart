import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/reports/base_report.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';

/// Report that generates a balance sheet
class BalanceSheetReport extends BaseReport {
  /// Creates a new balance sheet report generator
  ///
  /// @param services The services instance containing required services
  BalanceSheetReport(super.services);

  /// Generates a balance sheet report as of a specified date
  ///
  /// @param asOfDate The date for which to generate the balance sheet
  /// @return True if the report was successfully generated, false otherwise
  bool generate(DateTime asOfDate) {
    try {
      final generalJournalService = services.generalJournal;
      final chartOfAccounts = services.chartOfAccounts;

      // Get all asset, liability, and equity accounts
      final currentAssetAccounts =
          chartOfAccounts.getAccountsByType(AccountType.currentAsset);
      final bankAccounts = chartOfAccounts.getAccountsByType(AccountType.bank);
      final fixedAssetAccounts =
          chartOfAccounts.getAccountsByType(AccountType.fixedAsset);
      final inventoryAccounts =
          chartOfAccounts.getAccountsByType(AccountType.inventory);
      final liabilityAccounts =
          chartOfAccounts.getAccountsByType(AccountType.currentLiability);
      final equityAccounts =
          chartOfAccounts.getAccountsByType(AccountType.equity);

      // Calculate balances for each account as of the specified date
      final assetBalances = <String, double>{};
      final liabilityBalances = <String, double>{};
      final equityBalances = <String, double>{};

      double totalAssets = 0;
      double totalLiabilities = 0;
      double totalEquity = 0;

      // Process all asset accounts (current assets, bank accounts, fixed assets, and inventory)
      for (final account in [
        ...currentAssetAccounts,
        ...bankAccounts,
        ...fixedAssetAccounts,
        ...inventoryAccounts
      ]) {
        final balance = generalJournalService
            .calculateAccountBalance(account.code, asOfDate: asOfDate);
        if (balance != 0) {
          assetBalances[account.code] = balance;
          totalAssets += balance;
        }
      }

      // Process liability accounts
      for (final account in liabilityAccounts) {
        final balance = generalJournalService
            .calculateAccountBalance(account.code, asOfDate: asOfDate);
        if (balance != 0) {
          liabilityBalances[account.code] = balance;
          totalLiabilities += balance;
        }
      }

      // Process equity accounts
      for (final account in equityAccounts) {
        final balance = generalJournalService
            .calculateAccountBalance(account.code, asOfDate: asOfDate);

        // Check if account has transactions, even if balance is zero
        final transactions =
            getTransactionsForAccount(account.code, DateTime(1900), asOfDate);
        final hasTransactions = transactions.isNotEmpty;

        // Include the account if it has a non-zero balance OR if it has transactions
        if (balance != 0 || hasTransactions) {
          equityBalances[account.code] = balance;
          totalEquity += balance;
        }
      }

      // Calculate Owner's Equity as Assets minus Liabilities
      final ownerEquity = totalAssets - totalLiabilities;
      final ownerEquityAccount = equityAccounts.firstWhere(
        (account) => account.name.toLowerCase().contains("owner's equity"),
        orElse: () => Account(
          code: services.environment.ownersEquityAccountCode,
          name: "Owner's Equity",
          type: AccountType.equity,
          gst: false,
          gstType: GstType.basExcluded,
        ),
      );
      equityBalances[ownerEquityAccount.code] = ownerEquity;
      totalEquity = ownerEquity;

      // Generate HTML report
      final html = _generateHtml(
          asOfDate,
          assetBalances,
          liabilityBalances,
          equityBalances,
          totalAssets,
          totalLiabilities,
          totalEquity,
          chartOfAccounts);

      // Save the report to file
      final fileName =
          'balance_sheet_as_of_${formatDateForFileName(asOfDate)}.html';
      return saveReport(html, fileName);
    } catch (e) {
      print('Error generating Balance Sheet report: $e');
      return false;
    }
  }

  /// Generates the HTML content for the balance sheet report
  String _generateHtml(
      DateTime asOfDate,
      Map<String, double> assetBalances,
      Map<String, double> liabilityBalances,
      Map<String, double> equityBalances,
      double totalAssets,
      double totalLiabilities,
      double totalEquity,
      ChartOfAccountsService chartOfAccounts) {
    final buffer = StringBuffer();

    buffer.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Balance Sheet</title>
    <style>
$commonStyles
    </style>
$commonScripts
</head>
<body>
    <div class="report-header">
        <h1>Balance Sheet</h1>
        <div class="report-date">
            As of ${formatDateForDisplay(asOfDate)}
        </div>
    </div>
    
    <div class="report-info" style="text-align: center; margin-bottom: 20px; font-style: italic; color: #555;">
        Click on any account to view all historical transactions since account opening.
    </div>
    
    <div class="section">
        <div class="section-title">Assets</div>
        <table>
            <thead>
                <tr>
                    <th>Account</th>
                    <th class="amount-column">Amount</th>
                </tr>
            </thead>
            <tbody>
                ${_generateAccountRows(assetBalances, chartOfAccounts, asOfDate)}
                <tr class="total-row">
                    <td>Total Assets</td>
                    <td class="amount positive key-figure">${formatCurrency(totalAssets)}</td>
                </tr>
            </tbody>
        </table>
    </div>

    <div class="section">
        <div class="section-title">Liabilities</div>
        <table>
            <thead>
                <tr>
                    <th>Account</th>
                    <th class="amount-column">Amount</th>
                </tr>
            </thead>
            <tbody>
                ${_generateAccountRows(liabilityBalances, chartOfAccounts, asOfDate)}
                <tr class="total-row">
                    <td>Total Liabilities</td>
                    <td class="amount negative key-figure">${formatCurrency(totalLiabilities)}</td>
                </tr>
            </tbody>
        </table>
    </div>

    <div class="section">
        <div class="section-title">Equity</div>
        <table>
            <thead>
                <tr>
                    <th>Account</th>
                    <th class="amount-column">Amount</th>
                </tr>
            </thead>
            <tbody>
                ${_generateAccountRows(equityBalances, chartOfAccounts, asOfDate)}
                <tr class="total-row">
                    <td>Total Equity</td>
                    <td class="amount positive key-figure">${formatCurrency(totalEquity)}</td>
                </tr>
            </tbody>
        </table>
    </div>

    <div class="summary">
        <div class="summary-title">Balance Check</div>
        <table>
            <tbody>
                <tr class="item-group">
                    <td>Total Assets</td>
                    <td class="amount positive">${formatCurrency(totalAssets)}</td>
                </tr>
                <tr class="item-group">
                    <td>Total Liabilities + Equity</td>
                    <td class="amount positive">${formatCurrency(totalLiabilities + totalEquity)}</td>
                </tr>
                <tr class="net-item">
                    <td>Difference</td>
                    <td class="amount ${(totalAssets - (totalLiabilities + totalEquity)).abs() < 0.01 ? 'positive' : 'negative'} key-figure">${formatCurrency(totalAssets - (totalLiabilities + totalEquity))}</td>
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
  String _generateAccountRows(Map<String, double> accountBalances,
      ChartOfAccountsService chartOfAccounts, DateTime asOfDate) {
    final buffer = StringBuffer();
    for (final entry in accountBalances.entries) {
      final account = chartOfAccounts.getAccount(entry.key);
      if (account != null) {
        // Get all transactions for this account since the beginning of time
        final transactions = getTransactionsForAccount(
            account.code, DateTime(1900, 1, 1), asOfDate);
        buffer.write(generateAccountRow(
            account, entry.value, DateTime(1900, 1, 1), asOfDate,
            isPositive: entry.value >= 0,
            transactionCount: transactions.length));
      } else {
        // Handle special cases like Retained Earnings
        buffer.writeln('''
        <tr class="account-row">
            <td class="account-name">${entry.key} - Special Account</td>
            <td class="amount">${formatCurrency(entry.value)}</td>
        </tr>
''');
      }
    }
    return buffer.toString();
  }
}

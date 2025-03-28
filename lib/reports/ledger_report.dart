import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/reports/base_report.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';

/// Report that generates individual ledger accounts for all accounts with transactions
class LedgerReport extends BaseReport {
  /// Creates a new ledger report generator
  ///
  /// @param services The services instance containing required services
  LedgerReport(super.services);

  /// Generates individual ledger reports for each account with transactions in the specified date range
  ///
  /// @param startDate The start date of the report period
  /// @param endDate The end date of the report period
  /// @return True if all reports were successfully generated, false otherwise
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

      // Create a map of account codes to their transactions
      final accountTransactions = <String, List<_LedgerEntry>>{};

      // Process all entries to build account transactions
      for (final entry in entries) {
        // Process debits
        for (final debit in entry.debits) {
          accountTransactions.putIfAbsent(debit.accountCode, () => []);
          accountTransactions[debit.accountCode]!.add(_LedgerEntry(
            date: entry.date,
            description: entry.description,
            debit: debit.amount,
            credit: 0,
          ));
        }

        // Process credits
        for (final credit in entry.credits) {
          accountTransactions.putIfAbsent(credit.accountCode, () => []);
          accountTransactions[credit.accountCode]!.add(_LedgerEntry(
            date: entry.date,
            description: entry.description,
            debit: 0,
            credit: credit.amount,
          ));
        }
      }

      // Calculate running balances for each account
      for (final accountCode in accountTransactions.keys) {
        var runningBalance = 0.0;
        final account = chartOfAccounts.getAccount(accountCode);
        final isDebitNormal = account?.type == AccountType.currentAsset ||
            account?.type == AccountType.fixedAsset ||
            account?.type == AccountType.bank ||
            account?.type == AccountType.expense ||
            account?.type == AccountType.inventory;

        for (final transaction in accountTransactions[accountCode]!) {
          if (isDebitNormal) {
            runningBalance += transaction.debit - transaction.credit;
          } else {
            runningBalance += transaction.credit - transaction.debit;
          }
          transaction.balance = runningBalance;
        }
      }

      // Sort accounts by code
      final sortedAccounts = accountTransactions.keys.toList()..sort();

      // Generate individual HTML files for each account
      for (final accountCode in sortedAccounts) {
        final account = chartOfAccounts.getAccount(accountCode);
        if (account == null) continue;

        final transactions = accountTransactions[accountCode]!;
        final html =
            _generateHtmlForAccount(startDate, endDate, account, transactions);

        // Save individual account ledger
        final fileName =
            'ledger_${account.code}_${formatDateForFileName(startDate)}_to_${formatDateForFileName(endDate)}.html';
        if (!saveReport(html, fileName)) {
          return false;
        }
      }

      // Generate index file
      final indexHtml = _generateIndexHtml(
          startDate, endDate, sortedAccounts, chartOfAccounts);
      return saveReport(indexHtml, 'ledger_index.html');
    } catch (e) {
      print('Error generating Ledger reports: $e');
      return false;
    }
  }

  /// Generates the HTML content for the ledger index page
  String _generateIndexHtml(DateTime startDate, DateTime endDate,
      List<String> accountCodes, ChartOfAccountsService chartOfAccounts) {
    final buffer = StringBuffer();

    buffer.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>General Ledger - Account Index</title>
    <style>
$commonStyles
        .account-list {
            list-style: none;
            padding: 0;
        }
        .account-item {
            padding: 10px 15px;
            border-bottom: 1px solid #eee;
            display: flex;
            align-items: center;
            transition: background-color 0.2s;
        }
        .account-item:hover {
            background-color: #f8f9fa;
        }
        .account-code {
            color: #666;
            font-size: 0.9em;
            margin-right: 15px;
            min-width: 60px;
        }
        .account-name {
            flex-grow: 1;
        }
        .account-link {
            text-decoration: none;
            color: inherit;
            display: block;
        }
        .account-link:hover {
            color: #0066cc;
        }
    </style>
</head>
<body>
    <div class="report-header">
        <h1>General Ledger</h1>
        <div class="report-date">
            For the period ${formatDateForDisplay(startDate)} to ${formatDateForDisplay(endDate)}
        </div>
    </div>
    
    <div class="section">
        <div class="section-title">Account Ledgers</div>
        <ul class="account-list">
''');

    // Generate links to individual account ledgers
    for (final accountCode in accountCodes) {
      final account = chartOfAccounts.getAccount(accountCode);
      if (account == null) continue;

      final fileName =
          'ledger_${account.code}_${formatDateForFileName(startDate)}_to_${formatDateForFileName(endDate)}.html';

      buffer.writeln('''
            <li class="account-item">
                <a href="$fileName" class="account-link">
                    <span class="account-code">${account.code}</span>
                    <span class="account-name">${account.name}</span>
                </a>
            </li>
''');
    }

    buffer.writeln('''
        </ul>
    </div>
</body>
</html>
''');

    return buffer.toString();
  }

  /// Generates the HTML content for an individual account ledger
  String _generateHtmlForAccount(DateTime startDate, DateTime endDate,
      Account account, List<_LedgerEntry> transactions) {
    final buffer = StringBuffer();
    final isDebitNormal = account.type == AccountType.currentAsset ||
        account.type == AccountType.fixedAsset ||
        account.type == AccountType.bank ||
        account.type == AccountType.expense ||
        account.type == AccountType.inventory;

    buffer.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ledger - ${account.name}</title>
    <style>
$commonStyles
        .account-header {
            background-color: #f8f9fa;
            padding: 15px;
            border-bottom: 2px solid #ddd;
            margin-bottom: 20px;
        }
        .account-name {
            font-size: 1.4em;
            font-weight: bold;
            color: #333;
            display: block;
        }
        .account-code {
            color: #666;
            font-size: 1.1em;
            margin-top: 5px;
            display: block;
        }
        .account-type {
            color: #666;
            font-size: 0.9em;
            margin-top: 5px;
            display: block;
        }
        .ledger-table {
            width: 100%;
            border-collapse: collapse;
        }
        .ledger-table th {
            background-color: #f8f9fa;
            border-bottom: 2px solid #ddd;
            padding: 10px;
            text-align: left;
        }
        .ledger-table td {
            padding: 10px;
            border-bottom: 1px solid #eee;
        }
        .amount-cell {
            text-align: right;
            font-family: monospace;
            width: 120px;
        }
        .balance-cell {
            text-align: right;
            font-family: monospace;
            font-weight: bold;
            width: 120px;
        }
        .positive {
            color: #2c7c3c;
        }
        .negative {
            color: #c23838;
        }
        .back-link {
            display: inline-block;
            margin-bottom: 20px;
            color: #0066cc;
            text-decoration: none;
        }
        .back-link:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <a href="ledger_index.html" class="back-link">← Back to Account List</a>
    
    <div class="report-header">
        <h1>Account Ledger</h1>
        <div class="report-date">
            For the period ${formatDateForDisplay(startDate)} to ${formatDateForDisplay(endDate)}
        </div>
    </div>
    
    <div class="section">
        <div class="account-header">
            <span class="account-name">${account.name}</span>
            <span class="account-code">Account Code: ${account.code}</span>
            <span class="account-type">Account Type: ${account.type}</span>
        </div>
        
        <table class="ledger-table">
            <thead>
                <tr>
                    <th>Date</th>
                    <th>Description</th>
                    <th>Debit</th>
                    <th>Credit</th>
                    <th>Balance</th>
                </tr>
            </thead>
            <tbody>
''');

    for (final transaction in transactions) {
      final balanceClass = (isDebitNormal && transaction.balance >= 0) ||
              (!isDebitNormal && transaction.balance < 0)
          ? 'positive'
          : 'negative';

      buffer.writeln('''
                <tr>
                    <td>${formatDateForDisplay(transaction.date)}</td>
                    <td>${transaction.description}</td>
                    <td class="amount-cell">${transaction.debit > 0 ? formatCurrency(transaction.debit) : ''}</td>
                    <td class="amount-cell">${transaction.credit > 0 ? formatCurrency(transaction.credit) : ''}</td>
                    <td class="balance-cell ${balanceClass}">${formatCurrency(transaction.balance.abs())}</td>
                </tr>
''');
    }

    buffer.writeln('''
            </tbody>
        </table>
    </div>
</body>
</html>
''');

    return buffer.toString();
  }
}

/// Internal class to represent a ledger entry
class _LedgerEntry {
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  double balance = 0;

  _LedgerEntry({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
  });
}

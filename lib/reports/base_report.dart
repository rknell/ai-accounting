import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/services/services.dart';

/// Base class for all financial reports
abstract class BaseReport {
  /// The services instance containing required services
  final Services services;

  /// Creates a new base report
  ///
  /// @param services The services instance containing required services
  BaseReport(this.services);

  /// Formats a date for use in filenames
  ///
  /// @param date The date to format
  /// @return A string representation of the date in YYYY-MM-DD format
  String formatDateForFileName(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  /// Formats a date for display in reports
  ///
  /// @param date The date to format
  /// @return A string representation of the date in a human-readable format
  String formatDateForDisplay(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  /// Gets the name of a month from its number
  ///
  /// @param month The month number (1-12)
  /// @return The name of the month
  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  /// Formats a currency value for display
  ///
  /// @param value The currency value to format
  /// @return A string representation of the currency value
  String formatCurrency(double value) {
    final isNegative = value < 0;
    final absValue = value.abs();
    return '${isNegative ? '-' : ''}\$${absValue.toStringAsFixed(2)}';
  }

  /// Gets the common CSS styles used across all reports
  String get commonStyles => '''
        @page {
            size: A4;
            margin: 2cm;
        }
        body {
            font-family: 'Arial', sans-serif;
            line-height: 1.5;
            margin: 0;
            padding: 30px;
            background-color: white;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
        }
        .report-header {
            text-align: center;
            margin-bottom: 30px;
            border-bottom: 3px solid #333;
            padding-bottom: 15px;
        }
        .report-header h1 {
            font-size: 28px;
            margin-bottom: 5px;
            color: #1a1a1a;
            letter-spacing: 0.5px;
        }
        .report-date {
            text-align: center;
            margin-bottom: 40px;
            font-style: italic;
            font-size: 14px;
            color: #555;
        }
        .section {
            margin-bottom: 40px;
            background-color: #fff;
            border-radius: 6px;
            box-shadow: 0 1px 4px rgba(0,0,0,0.05);
            padding: 0 0 15px 0;
            overflow: hidden;
        }
        .section-title {
            font-weight: bold;
            margin-bottom: 15px;
            text-transform: uppercase;
            border-bottom: 1px solid #ddd;
            padding: 12px 15px;
            background-color: #f8f9fa;
            color: #333;
            font-size: 15px;
            letter-spacing: 0.5px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 0;
        }
        th {
            text-align: left;
            padding: 12px 15px;
            border-bottom: 2px solid #ddd;
            font-weight: bold;
            background-color: #f8f9fa;
            color: #505050;
        }
        td {
            padding: 10px 15px;
            border-bottom: 1px solid #eee;
        }
        tr:hover {
            background-color: rgba(0,0,0,0.01);
        }
        .amount-column {
            text-align: right;
        }
        .account-row {
            cursor: pointer;
            transition: background-color 0.15s ease-in-out;
        }
        .account-row:hover {
            background-color: #f5f9ff;
        }
        .account-name {
            width: 70%;
            font-size: 14px;
        }
        .inline-count {
            font-style: italic;
            color: #999;
            font-size: 13px;
            margin-left: 8px;
            font-weight: normal;
        }
        .amount {
            width: 30%;
            text-align: right;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            font-weight: 500;
            color: #333; /* Default color for all amounts */
        }
        .total-row {
            font-weight: bold;
            border-top: 2px solid #ddd;
            border-bottom: 3px double #aaa;
            background-color: #f8f9fa;
        }
        .total-row td {
            padding: 12px 15px;
        }
        /* Only apply color to totals and summary rows */
        .total-row .positive, 
        .summary .positive,
        .net-item .positive {
            color: #2c7c3c;
        }
        .total-row .negative, 
        .summary .negative,
        .net-item .negative {
            color: #c23838;
        }
        
        /* Sub-section styling */
        .sub-section {
            margin-left: 20px;
            margin-bottom: 15px;
        }
        .sub-section-title {
            font-weight: 600;
            padding: 8px 0;
            font-size: 14px;
            color: #555;
        }
        
        /* Summary section styles */
        .summary {
            margin-top: 40px;
            border: 1px solid #ddd;
            border-radius: 6px;
            padding: 0 0 15px 0;
            overflow: hidden;
        }
        .summary-title {
            font-weight: bold;
            padding: 12px 15px;
            text-transform: uppercase;
            background-color: #f0f3f5;
            border-bottom: 1px solid #ddd;
            color: #333;
            font-size: 15px;
            letter-spacing: 0.5px;
        }
        .summary table {
            margin-bottom: 0;
        }
        .summary tr:last-child td {
            border-bottom: none;
        }
        .net-item {
            font-weight: bold;
            border-top: 1px solid #ddd;
        }
        .net-item td {
            padding-top: 12px;
            font-size: 16px;
        }
        .payable {
            font-weight: bold;
            color: #c23838;
        }
        .refund {
            font-weight: bold;
            color: #2c7c3c;
        }
        
        /* Special styling for key metrics */
        .key-figure {
            font-size: 16px;
            font-weight: 600;
        }
        
        /* Group related items with subtle dividers */
        .item-group + .item-group {
            border-top: 1px dashed #eee;
            margin-top: 5px;
            padding-top: 5px;
        }
        
        /* Print styles */
        @media print {
            body {
                padding: 0;
                max-width: none;
            }
            .section {
                box-shadow: none;
                border: 1px solid #ddd;
                page-break-inside: avoid;
            }
            .no-print {
                display: none;
            }
            .summary {
                page-break-inside: avoid;
            }
        }
        /* Transaction panel styles */
        .transaction-panel {
            position: fixed;
            top: 0;
            right: -450px;
            width: 400px;
            height: 100vh;
            background-color: white;
            box-shadow: -2px 0 15px rgba(0,0,0,0.1);
            transition: right 0.3s ease-in-out;
            z-index: 1000;
            padding: 20px;
            overflow-y: auto;
            visibility: hidden;
            border-left: 1px solid #ddd;
        }
        .transaction-panel.open {
            right: 0;
            visibility: visible;
        }
        .transaction-panel-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 1px solid #ddd;
        }
        .transaction-panel-title {
            font-weight: bold;
            font-size: 16px;
        }
        .close-button {
            background: none;
            border: none;
            font-size: 20px;
            cursor: pointer;
            color: #777;
        }
        .transaction-list {
            margin-top: 20px;
        }
        .transaction-count {
            margin: 10px 0;
            font-weight: bold;
            color: #555;
            border-bottom: 1px solid #eee;
            padding-bottom: 12px;
        }
        .transaction-item {
            padding: 12px;
            border-bottom: 1px solid #eee;
        }
        .transaction-date {
            color: #666;
            font-size: 13px;
        }
        .transaction-description {
            margin: 8px 0;
            font-size: 14px;
        }
        .transaction-amount {
            text-align: right;
            font-weight: 600;
            font-family: 'Courier New', monospace;
            margin-top: 5px;
        }
        /* Only colorize transaction amounts in the panel for clarity */
        .transaction-amount.positive {
            color: #2c7c3c;
        }
        .transaction-amount.negative {
            color: #c23838;
        }
        .transaction-info {
            margin: 8px 0 15px;
            color: #666;
            font-size: 13px;
            background-color: #f8f9fa;
            padding: 10px;
            border-radius: 4px;
            border-left: 3px solid #ddd;
        }
        .overlay {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0,0,0,0.3);
            z-index: 999;
        }
        .overlay.open {
            display: block;
        }
    ''';

  /// Gets the common JavaScript used across all reports
  String get commonScripts => '''
    <script>
        // Global object to store transaction data by account code
        const accountTransactions = {};
        
        function showTransactions(accountCode, accountName) {
            const panel = document.getElementById('transaction-panel');
            const overlay = document.getElementById('overlay');
            const title = document.getElementById('panel-title');
            const list = document.getElementById('transaction-list');
            
            title.textContent = accountName;
            list.innerHTML = '';
            
            const transactions = accountTransactions[accountCode] || [];
            
            // Add transaction count display
            const countDisplay = document.createElement('div');
            countDisplay.className = 'transaction-count';
            countDisplay.textContent = transactions.length + ' transactions found';
            list.appendChild(countDisplay);
            
            // Add helpful message for large transaction sets
            if (transactions.length > 50) {
                const infoMessage = document.createElement('div');
                infoMessage.className = 'transaction-info';
                infoMessage.innerHTML = '<em>Showing all historical transactions from account opening until report date.</em>';
                list.appendChild(infoMessage);
            }
            
            transactions.forEach(function(transaction) {
                const item = document.createElement('div');
                item.className = 'transaction-item';
                
                const amountClass = transaction.amount >= 0 ? 'positive' : 'negative';
                const amountPrefix = transaction.amount >= 0 ? '+' : '';
                
                item.innerHTML = 
                    '<div class="transaction-date">' + transaction.date + '</div>' +
                    '<div class="transaction-description">' + transaction.description + '</div>' +
                    '<div class="transaction-amount ' + amountClass + '">' +
                    amountPrefix + transaction.amount.toFixed(2) +
                    '</div>';
                list.appendChild(item);
            });
            
            panel.classList.add('open');
            overlay.classList.add('open');
            
            // Reset scroll position to top
            panel.scrollTop = 0;
        }
        
        function closePanel() {
            const panel = document.getElementById('transaction-panel');
            const overlay = document.getElementById('overlay');
            panel.classList.remove('open');
            overlay.classList.remove('open');
        }
        
        document.addEventListener('DOMContentLoaded', function() {
            const overlay = document.getElementById('overlay');
            overlay.addEventListener('click', closePanel);
        });
    </script>
  ''';

  /// Gets the common transaction panel HTML used across all reports
  String get commonTransactionPanel => '''
    <div id="overlay" class="overlay"></div>
    <div id="transaction-panel" class="transaction-panel">
        <div class="transaction-panel-header">
            <div id="panel-title" class="transaction-panel-title"></div>
            <button class="close-button" onclick="closePanel()">&times;</button>
        </div>
        <div id="transaction-list" class="transaction-list"></div>
    </div>
  ''';

  /// Gets all transactions for an account within a date range
  List<GeneralJournal> getTransactionsForAccount(
      String accountCode, DateTime startDate, DateTime endDate) {
    // Get all entries from the journal that involve this account
    return services.generalJournal.entries
        .where((entry) =>
            (entry.debits.any((debit) => debit.accountCode == accountCode) ||
                entry.credits
                    .any((credit) => credit.accountCode == accountCode)) &&
            entry.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            entry.date.isBefore(endDate.add(const Duration(days: 1))))
        .toList();
  }

  /// Calculates the net amount for an account in a specific transaction
  ///
  /// For a given account and transaction, calculates the net effect (positive or negative)
  /// taking into account whether the account was debited or credited and the account type.
  ///
  /// @param entry The journal entry containing the transaction
  /// @param accountCode The account code to calculate the amount for
  /// @param isPositive Whether amounts should be considered positive when credited to this account
  /// @return The net amount for this account in this transaction
  double getTransactionAmountForAccount(
      GeneralJournal entry, String accountCode,
      {bool isPositive = true}) {
    // Calculate the total amount debited to this account in this entry
    double debitAmount = 0.0;
    for (final debit in entry.debits) {
      if (debit.accountCode == accountCode) {
        debitAmount += debit.amount;
      }
    }

    // Calculate the total amount credited to this account in this entry
    double creditAmount = 0.0;
    for (final credit in entry.credits) {
      if (credit.accountCode == accountCode) {
        creditAmount += credit.amount;
      }
    }

    // Determine the net effect based on whether credits are considered positive for this account
    if (isPositive) {
      return creditAmount - debitAmount;
    } else {
      return debitAmount - creditAmount;
    }
  }

  /// Encodes a JSON object to a string for use in HTML
  String encodeJson(List<Map<String, dynamic>> json) {
    // Process each item to ensure correct escaping
    final processedItems = json
        .map((item) => {
              'date': item['date'],
              'description': item['description'],
              'amount': item['amount'],
            })
        .toList();

    // Use the JSON encoder to properly encode the data
    return jsonEncode(processedItems);
  }

  /// Generates HTML for an account row with transaction panel support
  String generateAccountRow(
      Account account, double value, DateTime startDate, DateTime endDate,
      {bool isPositive = true, int transactionCount = 0}) {
    final transactions =
        getTransactionsForAccount(account.code, startDate, endDate);
    final transactionsJson = transactions
        .map((t) => {
              'date': formatDateForDisplay(t.date),
              // Sanitize description for display
              'description': t.description
                  .replaceAll('\n', ' ')
                  .replaceAll('\r', ' ')
                  .replaceAll('\t', ' '),
              'amount': getTransactionAmountForAccount(t, account.code,
                  isPositive: isPositive),
            })
        .toList();

    // Escape apostrophes and other special characters in the account name
    final escapedName =
        account.name.replaceAll("'", "\\'").replaceAll('"', '\\"');

    // Generate JavaScript for storing transaction data
    final transactionsScript = '''
    <script>
        accountTransactions['${account.code}'] = ${jsonEncode(transactionsJson)};
    </script>
    ''';

    return '''
        $transactionsScript
        <tr class="account-row" onclick="showTransactions('${account.code}', '$escapedName')">
            <td class="account-name">${account.code} - ${account.name} <span class="inline-count">(${transactionCount} txn)</span></td>
            <td class="amount">${formatCurrency(value)}</td>
        </tr>
''';
  }

  /// Saves the report HTML to a file
  ///
  /// @param html The HTML content to save
  /// @param fileName The name of the file to save to
  /// @return True if the file was saved successfully, false otherwise
  bool saveReport(String html, String fileName) {
    try {
      final file = File('data/$fileName');
      file.writeAsStringSync(html);
      print('Report generated: ${file.path}');
      return true;
    } catch (e) {
      print('Error saving report: $e');
      return false;
    }
  }
}

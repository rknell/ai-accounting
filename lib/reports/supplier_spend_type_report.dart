import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/supplier_spend_type.dart';
import 'package:ai_accounting/reports/base_report.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:ai_accounting/services/supplier_spend_type_service.dart';
import 'package:ai_accounting/utils/supplier_note_parser.dart';
import 'package:meta/meta.dart';

/// Generates a quarterly view of spend split by supplier cadence (fixed/variable/one-time).
class SupplierSpendTypeReport extends BaseReport {
  /// Creates a report generator bound to [services] and the shared spend-type service.
  SupplierSpendTypeReport({
    required Services services,
    SupplierSpendTypeService? spendTypeService,
  })  : _spendTypeService = spendTypeService ?? services.supplierSpendTypes,
        super(services);

  final SupplierSpendTypeService _spendTypeService;

  /// Builds and writes the report for the supplied date range.
  bool generate(DateTime startDate, DateTime endDate) {
    try {
      final entries =
          services.generalJournal.getEntriesByDateRange(startDate, endDate);
      if (entries.isEmpty) {
        print(
            '⚠️  No transactions found between ${startDate.toIso8601String()} and ${endDate.toIso8601String()} – skipping Supplier Spend report.');
        return false;
      }

      final breakdown = buildBreakdown(entries);
      final html = _buildHtml(startDate, endDate, breakdown);
      final fileName =
          'supplier_spend_${formatDateForFileName(startDate)}_to_${formatDateForFileName(endDate)}.html';
      return saveReport(html, fileName);
    } catch (e, stackTrace) {
      print('❌ Error generating Supplier Spend report: $e');
      print(stackTrace);
      return false;
    }
  }

  /// Aggregates [entries] into cadence buckets for rendering.
  @visibleForTesting
  SupplierSpendBreakdown buildBreakdown(List<GeneralJournal> entries) {
    final buckets = {
      for (final type in SupplierSpendType.values)
        type: SupplierSpendBucket(type),
    };
    final uncategorized = <SupplierSpendTransaction>[];

    for (final entry in entries) {
      final supplierFromNotes = SupplierNoteParser.extractSupplier(entry.notes);
      SupplierSpendTypeMapping? mapping;
      if (supplierFromNotes != null && supplierFromNotes.isNotEmpty) {
        mapping = _spendTypeService.ensureSupplierEntry(supplierFromNotes);
      } else {
        mapping = _spendTypeService.findInText(entry.description) ??
            _spendTypeService.findInText(entry.notes);
      }

      final resolvedSupplier =
          supplierFromNotes ?? mapping?.supplierName ?? entry.description;

      final transaction = SupplierSpendTransaction(
        supplierName: resolvedSupplier,
        amount: entry.amount,
        date: entry.date,
        description: entry.description,
        notes: entry.notes,
      );

      final targetType = mapping?.type;
      if (targetType != null) {
        buckets[targetType]!.transactions.add(transaction);
      } else {
        uncategorized.add(transaction);
      }
    }

    return SupplierSpendBreakdown(
      buckets: buckets,
      uncategorized: uncategorized,
    );
  }

  String _buildHtml(
      DateTime startDate, DateTime endDate, SupplierSpendBreakdown breakdown) {
    final buffer = StringBuffer();
    final totalSpend = breakdown.totalAmount;

    buffer.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Supplier Spend Type Breakdown</title>
    <style>
$commonStyles
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 18px;
            margin-bottom: 25px;
        }
        .summary-card {
            border: 1px solid #e4e4e4;
            border-radius: 10px;
            padding: 18px;
            background: linear-gradient(180deg, #fdfdfd 0%, #f7f9fc 100%);
        }
        .summary-card h3 {
            margin: 0 0 10px 0;
            font-size: 16px;
            letter-spacing: 0.4px;
        }
        .summary-value {
            font-size: 24px;
            font-weight: bold;
            margin-bottom: 6px;
        }
        .summary-meta {
            color: #555;
            font-size: 13px;
        }
        .supplier-table td:first-child {
            width: 45%;
        }
        .tag {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 999px;
            font-size: 12px;
            background-color: #eef2ff;
            color: #3949ab;
        }
        .uncategorized-banner {
            border: 1px dashed #f0b429;
            padding: 12px 16px;
            border-radius: 6px;
            background: #fffaf2;
            margin-bottom: 15px;
            color: #8a5a00;
        }
    </style>
</head>
<body>
  <div class="report-header">
      <h1>Supplier Spend Type Breakdown</h1>
      <div class="report-date">
          For the period ${formatDateForDisplay(startDate)} to ${formatDateForDisplay(endDate)}
      </div>
  </div>

  <div class="section">
      <div class="section-title">Overview</div>
      <div class="summary-grid">
${SupplierSpendType.values.map((type) => _buildSummaryCard(type, breakdown, totalSpend)).join('\n')}
      </div>
  </div>

  <div class="section">
      <div class="section-title">Supplier Breakdown by Type</div>
${SupplierSpendType.values.map((type) => _buildSupplierTable(type, breakdown)).join('\n')}
  </div>

  <div class="section">
      <div class="section-title">Transactions</div>
${SupplierSpendType.values.map((type) => _buildTransactionTable(type, breakdown)).join('\n')}
${_buildUncategorizedSection(breakdown)}
  </div>
</body>
</html>
''');
    return buffer.toString();
  }

  String _buildSummaryCard(SupplierSpendType type,
      SupplierSpendBreakdown breakdown, double totalSpend) {
    final bucket = breakdown.buckets[type]!;
    final total = bucket.totalAmount;
    final share = totalSpend == 0 ? 0 : (total / totalSpend) * 100;
    final label = SupplierSpendTypeHelper.displayLabel(type);

    return '''
        <div class="summary-card">
            <h3>$label Spend</h3>
            <div class="summary-value">${formatCurrency(total)}</div>
            <div class="summary-meta">
                ${bucket.transactionCount} transactions · ${share.toStringAsFixed(1)}% of tracked spend
            </div>
        </div>
''';
  }

  String _buildSupplierTable(
      SupplierSpendType type, SupplierSpendBreakdown breakdown) {
    final bucket = breakdown.buckets[type]!;
    if (bucket.transactions.isEmpty) {
      return '''
        <p><strong>${SupplierSpendTypeHelper.displayLabel(type)}:</strong> No supplier activity recorded.</p>
      ''';
    }

    final rows = bucket.supplierTotals.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    final tableRows = rows.map((entry) {
      final stats = entry.value;
      return '''
        <tr>
            <td>${entry.key}<br/><span class="tag">${stats.transactionCount} txn</span></td>
            <td class="amount-column">${formatCurrency(stats.total)}</td>
        </tr>
''';
    }).join('\n');

    return '''
      <div class="sub-section">
          <div class="sub-section-title">${SupplierSpendTypeHelper.displayLabel(type)}</div>
          <table class="supplier-table">
              <thead>
                  <tr>
                      <th>Supplier</th>
                      <th class="amount-column">Total Spend</th>
                  </tr>
              </thead>
              <tbody>
$tableRows
              </tbody>
          </table>
      </div>
''';
  }

  String _buildTransactionTable(
      SupplierSpendType type, SupplierSpendBreakdown breakdown) {
    final bucket = breakdown.buckets[type]!;
    if (bucket.transactions.isEmpty) {
      return '';
    }

    final rows = bucket.transactions.map((transaction) => '''
        <tr>
            <td>${formatDateForDisplay(transaction.date)}</td>
            <td>${transaction.supplierName}</td>
            <td>${transaction.description}</td>
            <td class="amount-column">${formatCurrency(transaction.amount)}</td>
        </tr>
''').join('\n');

    return '''
      <div class="sub-section">
          <div class="sub-section-title">${SupplierSpendTypeHelper.displayLabel(type)} Transactions</div>
          <table>
              <thead>
                  <tr>
                      <th>Date</th>
                      <th>Supplier</th>
                      <th>Description</th>
                      <th class="amount-column">Amount</th>
                  </tr>
              </thead>
              <tbody>
$rows
              </tbody>
          </table>
      </div>
''';
  }

  String _buildUncategorizedSection(SupplierSpendBreakdown breakdown) {
    if (breakdown.uncategorized.isEmpty) {
      return '';
    }

    final rows = breakdown.uncategorized.map((transaction) => '''
        <tr>
            <td>${formatDateForDisplay(transaction.date)}</td>
            <td>${transaction.supplierName}</td>
            <td>${transaction.description}</td>
            <td>${transaction.notes}</td>
            <td class="amount-column">${formatCurrency(transaction.amount)}</td>
        </tr>
''').join('\n');

    return '''
      <div class="uncategorized-banner">
          ${breakdown.uncategorized.length} transactions lacked a supplier mapping.
          Update config/supplier_spend_types.json to classify them.
      </div>
      <table>
          <thead>
              <tr>
                  <th>Date</th>
                  <th>Supplier</th>
                  <th>Description</th>
                  <th>Notes</th>
                  <th class="amount-column">Amount</th>
              </tr>
          </thead>
          <tbody>
$rows
          </tbody>
      </table>
''';
  }
}

/// Aggregated supplier spend data grouped by cadence.
class SupplierSpendBreakdown {
  /// Creates a breakdown using the supplied bucket map.
  SupplierSpendBreakdown({
    required this.buckets,
    required this.uncategorized,
  });

  /// Map of cadence type → bucket data.
  final Map<SupplierSpendType, SupplierSpendBucket> buckets;

  /// Transactions that could not be mapped to a cadence.
  final List<SupplierSpendTransaction> uncategorized;

  /// Total tracked spend for the entire period.
  double get totalAmount =>
      buckets.values.fold(0.0, (sum, bucket) => sum + bucket.totalAmount);
}

/// Bucket of transactions for a spend cadence type.
class SupplierSpendBucket {
  /// Creates a bucket bound to [type].
  SupplierSpendBucket(this.type);

  /// Cadence represented by this bucket.
  final SupplierSpendType type;

  /// Transactions included in the bucket.
  final List<SupplierSpendTransaction> transactions = [];

  /// Total spent across all transactions in this bucket.
  double get totalAmount =>
      transactions.fold(0.0, (sum, txn) => sum + txn.amount);

  /// Number of transactions assigned to the bucket.
  int get transactionCount => transactions.length;

  /// Totals grouped by supplier within the bucket.
  Map<String, SupplierSpendSupplierStats> get supplierTotals {
    final map = <String, SupplierSpendSupplierStats>{};
    for (final transaction in transactions) {
      map.update(
        transaction.supplierName,
        (existing) => existing.addAmount(transaction.amount),
        ifAbsent: () => SupplierSpendSupplierStats(
            total: transaction.amount, transactionCount: 1),
      );
    }
    return map;
  }
}

/// Summarised supplier totals inside a bucket.
class SupplierSpendSupplierStats {
  /// Creates supplier-level totals for a cadence bucket.
  const SupplierSpendSupplierStats({
    required this.total,
    required this.transactionCount,
  });

  /// Aggregate amount spent with the supplier.
  final double total;

  /// Number of transactions attributed to the supplier.
  final int transactionCount;

  /// Returns a copy with [amount] added to the running totals.
  SupplierSpendSupplierStats addAmount(double amount) {
    return SupplierSpendSupplierStats(
      total: total + amount,
      transactionCount: transactionCount + 1,
    );
  }
}

/// Lightweight transaction view used by the report rendering.
class SupplierSpendTransaction {
  /// Creates a record of a single supplier transaction.
  SupplierSpendTransaction({
    required this.supplierName,
    required this.amount,
    required this.date,
    required this.description,
    required this.notes,
  });

  /// Supplier name resolved for the transaction.
  final String supplierName;

  /// Transaction amount (always positive).
  final double amount;

  /// Date the transaction was booked.
  final DateTime date;

  /// Original description from the journal entry.
  final String description;

  /// Notes captured on the journal entry (usually contains supplier metadata).
  final String notes;
}

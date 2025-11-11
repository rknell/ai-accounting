import 'dart:io';

import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/models/split_transaction.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:ai_accounting/utils/supplier_note_parser.dart';

/// Exports a single-line-per-transaction CSV focused on categorised accounts.
class TransactionSummaryCsvExporter {
  /// Creates a transaction summary exporter bound to shared [services].
  TransactionSummaryCsvExporter(
    this.services, {
    String? gstClearingAccountCode,
  }) : gstClearingAccountCode = gstClearingAccountCode ?? '506';

  /// Shared gateway to journal + chart-of-accounts data.
  final Services services;

  /// Account code treated as GST clearing and therefore excluded from rows.
  final String gstClearingAccountCode;

  static const _header =
      'Date,Description,Supplier,Account Name,Account Code,Credit,Debit';

  /// Builds the transaction summary CSV for the provided [entries].
  ///
  /// When [entries] is omitted the exporter uses `services.generalJournal`.
  String buildCsv({Iterable<GeneralJournal>? entries}) {
    final sourceEntries =
        entries?.toList() ?? services.generalJournal.getAllEntries().toList();
    sourceEntries.sort((a, b) => a.date.compareTo(b.date));

    final buffer = StringBuffer()..writeln(_header);
    for (final entry in sourceEntries) {
      buffer.writeln(_buildRow(entry));
    }
    return buffer.toString();
  }

  /// Writes the summary CSV to [outputPath], creating directories if needed.
  File exportToFile(String outputPath, {Iterable<GeneralJournal>? entries}) {
    final csv = buildCsv(entries: entries);
    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(csv);
    return file;
  }

  String _buildRow(GeneralJournal entry) {
    final date = _formatDate(entry.date);
    final description = _formatDescription(entry.description);
    final supplier =
        _escapeCsv(SupplierNoteParser.extractSupplier(entry.notes) ?? '');

    final candidate = _findPrimarySplit(entry);
    final accountName =
        _escapeCsv(_resolveAccountName(candidate?.split.accountCode));
    final accountCode = _escapeCsv(candidate?.split.accountCode ?? '');
    final credit = candidate == null
        ? ''
        : candidate.isDebit
            ? ''
            : _formatAmount(candidate.split.amount);
    final debit = candidate == null
        ? ''
        : candidate.isDebit
            ? _formatAmount(candidate.split.amount)
            : '';

    return [
      date,
      description,
      supplier,
      accountName,
      accountCode,
      credit,
      debit,
    ].join(',');
  }

  _PrimarySplit? _findPrimarySplit(GeneralJournal entry) {
    for (final debit in entry.debits) {
      if (_isCandidateAccount(debit.accountCode)) {
        return _PrimarySplit(split: debit, isDebit: true);
      }
    }
    for (final credit in entry.credits) {
      if (_isCandidateAccount(credit.accountCode)) {
        return _PrimarySplit(split: credit, isDebit: false);
      }
    }
    return null;
  }

  bool _isCandidateAccount(String accountCode) {
    if (accountCode == gstClearingAccountCode) {
      return false;
    }
    final account = services.chartOfAccounts.getAccount(accountCode);
    if (account == null) {
      // Unknown accounts are treated as candidates so nothing is hidden.
      return true;
    }
    return account.type != AccountType.bank;
  }

  String _resolveAccountName(String? accountCode) {
    if (accountCode == null || accountCode.isEmpty) {
      return 'Bank/GST Only Transaction';
    }
    final account = services.chartOfAccounts.getAccount(accountCode);
    if (account != null) {
      return account.name;
    }
    return 'Unknown Account ($accountCode)';
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatAmount(double amount) => amount.toStringAsFixed(2);

  String _escapeCsv(String value) {
    if (value.isEmpty) {
      return '';
    }
    var escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n')) {
      escaped = '"$escaped"';
    }
    return escaped;
  }

  String _formatDescription(String description) {
    if (description.isEmpty) {
      return '';
    }
    final escaped = _escapeCsv(description);
    if (escaped.startsWith('"') && escaped.endsWith('"')) {
      return escaped;
    }
    return '"$escaped"';
  }
}

class _PrimarySplit {
  const _PrimarySplit({required this.split, required this.isDebit});

  final SplitTransaction split;
  final bool isDebit;
}

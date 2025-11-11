import 'dart:io';

import 'package:ai_accounting/models/general_journal.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:ai_accounting/utils/supplier_note_parser.dart';

/// Exports the general journal to a CSV file with flattened debit/credit rows.
class GeneralJournalCsvExporter {
  /// Creates an exporter bound to the shared [Services] instance.
  GeneralJournalCsvExporter(this.services);

  /// Access to shared application services.
  final Services services;

  static const _header =
      'Date,Description,Supplier,Account Name,Account Code,Credit,Debit';

  /// Builds the CSV contents for the provided [entries].
  ///
  /// When [entries] is omitted, the exporter reads from `services.generalJournal`.
  String buildCsv({Iterable<GeneralJournal>? entries}) {
    final sourceEntries =
        entries?.toList() ?? services.generalJournal.getAllEntries().toList();
    sourceEntries.sort((a, b) => a.date.compareTo(b.date));

    final buffer = StringBuffer()..writeln(_header);
    for (final entry in sourceEntries) {
      final date = _formatDate(entry.date);
      final description = _escapeCsv(entry.description);
      final supplier =
          _escapeCsv(SupplierNoteParser.extractSupplier(entry.notes) ?? '');

      for (final debit in entry.debits) {
        final accountName = _resolveAccountName(debit.accountCode);
        buffer.writeln(
          [
            date,
            description,
            supplier,
            _escapeCsv(accountName),
            _escapeCsv(debit.accountCode),
            '',
            _formatAmount(debit.amount),
          ].join(','),
        );
      }

      for (final credit in entry.credits) {
        final accountName = _resolveAccountName(credit.accountCode);
        buffer.writeln(
          [
            date,
            description,
            supplier,
            _escapeCsv(accountName),
            _escapeCsv(credit.accountCode),
            _formatAmount(credit.amount),
            '',
          ].join(','),
        );
      }
    }

    return buffer.toString();
  }

  /// Writes the CSV contents to [outputPath] (directories are created if needed).
  File exportToFile(String outputPath, {Iterable<GeneralJournal>? entries}) {
    final csv = buildCsv(entries: entries);
    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(csv);
    return file;
  }

  String _resolveAccountName(String accountCode) {
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
}

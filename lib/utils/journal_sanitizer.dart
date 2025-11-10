/// Signature for log callbacks used by [JournalSanitizer].
typedef JournalSanitizerLog = void Function(String message);

/// Utility helpers to sanitize general journal JSON payloads.
class JournalSanitizer {
  const JournalSanitizer._();

  /// Removes non-positive split amounts and normalizes entry payloads.
  static Map<String, dynamic> sanitizeEntry(
    Map<String, dynamic> entry, {
    JournalSanitizerLog? log,
  }) {
    return {
      ...entry,
      'debits': _sanitizeSplits(
          entry['debits'] as List<dynamic>?, 'debit', entry, log),
      'credits': _sanitizeSplits(
          entry['credits'] as List<dynamic>?, 'credit', entry, log),
    };
  }

  static List<Map<String, dynamic>> _sanitizeSplits(
    List<dynamic>? splits,
    String side,
    Map<String, dynamic> entry,
    JournalSanitizerLog? log,
  ) {
    if (splits == null) {
      return const [];
    }

    final cleaned = <Map<String, dynamic>>[];
    for (final raw in splits) {
      final split = Map<String, dynamic>.from(raw as Map<String, dynamic>);
      final amountValue = (split['amount'] as num?)?.toDouble() ?? 0.0;
      final sanitizedAmount = amountValue.abs();
      if (sanitizedAmount <= 0) {
        _logSanitization(side, entry, amountValue, log);
        continue;
      }
      if (sanitizedAmount != amountValue) {
        _logSanitization(side, entry, amountValue, log);
      }
      cleaned.add({
        ...split,
        'amount': double.parse(sanitizedAmount.toStringAsFixed(2)),
      });
    }
    return cleaned;
  }

  static void _logSanitization(String side, Map<String, dynamic> entry,
      double amount, JournalSanitizerLog? log) {
    if (log == null) {
      return;
    }
    final description = entry['description'] ?? 'unknown description';
    final date = entry['date'] ?? 'unknown date';
    log('⚠️  Sanitized $side split with invalid amount $amount for "$description" on $date');
  }
}

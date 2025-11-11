/// Utility helper for extracting supplier metadata from journal entry notes.
class SupplierNoteParser {
  static final RegExp _supplierPattern = RegExp(r'Supplier:\s*([^\n|]+)');
  static final RegExp _confidencePattern =
      RegExp(r'\(confidence[:\s][^)]+\)$', caseSensitive: false);

  /// Extracts the supplier name from the provided [notes] string.
  ///
  /// The parser understands the `Supplier: <name> (confidence: 92%)` structure
  /// written by the categorisation workflow and trims any trailing confidence
  /// annotations. Returns `null` if no supplier hint is present.
  static String? extractSupplier(String? notes) {
    if (notes == null || notes.trim().isEmpty) {
      return null;
    }

    final match = _supplierPattern.firstMatch(notes);
    if (match == null) {
      return null;
    }

    final captured = match.group(1);
    if (captured == null) {
      return null;
    }

    final cleaned = captured.replaceAll(_confidencePattern, '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }
}

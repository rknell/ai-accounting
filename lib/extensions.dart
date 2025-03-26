/// Extension on String to parse Australian date format
extension DateParsingExtension on String {
  /// Parses a string in Australian date format (DD/MM/YYYY) to DateTime
  /// Falls back to standard DateTime.parse if not in expected format
  /// Returns epoch date (1970-01-01) if parsing fails
  DateTime parseAustralianDate() {
    try {
      // Split the date string by '/'
      final parts = split('/');
      if (parts.length == 3) {
        // Australian format: DD/MM/YYYY
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
      // Fallback to standard parsing if not in expected format
      return DateTime.parse(this);
    } catch (e) {
      print('Error parsing date "$this": $e');
      // Return a default date if parsing fails
      return DateTime(1970, 1, 1);
    }
  }
}

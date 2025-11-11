/// Expense cadence classifications used by the Supplier Spend report.
enum SupplierSpendType {
  /// Recurring commitments with predictable cadence (e.g. rent, subscriptions).
  fixed,

  /// Operational outflows that scale with activity (e.g. packaging, freight).
  variable,

  /// Ad-hoc purchases that rarely repeat (e.g. tooling, one-off repairs).
  oneTime,
}

/// Helper utilities for working with [SupplierSpendType] values.
class SupplierSpendTypeHelper {
  static const Map<SupplierSpendType, String> _storageValues = {
    SupplierSpendType.fixed: 'fixed',
    SupplierSpendType.variable: 'variable',
    SupplierSpendType.oneTime: 'one_time',
  };

  static const Map<SupplierSpendType, String> _displayLabels = {
    SupplierSpendType.fixed: 'Fixed',
    SupplierSpendType.variable: 'Variable',
    SupplierSpendType.oneTime: 'One Time',
  };

  /// Converts a stored string (e.g. JSON/config value) into a [SupplierSpendType].
  static SupplierSpendType? fromString(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized =
        raw.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    for (final entry in _storageValues.entries) {
      if (entry.value == normalized) {
        return entry.key;
      }
    }
    return null;
  }

  /// Returns the canonical storage value for [type] (e.g. `one_time`).
  static String? storageValue(SupplierSpendType? type) {
    if (type == null) {
      return null;
    }
    return _storageValues[type] ?? 'fixed';
  }

  /// Returns the human friendly label used in reports.
  static String displayLabel(SupplierSpendType type) =>
      _displayLabels[type] ?? 'Fixed';
}

/// Strongly typed supplier-to-spend-type mapping entry.
class SupplierSpendTypeMapping {
  /// Creates a mapping between a supplier name, cadence type, and optional AI hints.
  const SupplierSpendTypeMapping({
    required this.supplierName,
    required this.type,
    List<String>? aliases,
    List<String>? hints,
  })  : aliases = aliases ?? const [],
        hints = hints ?? const [];

  /// Supplier name exactly as written in categorisation notes.
  final String supplierName;

  /// Classification assigned to transactions for this supplier.
  final SupplierSpendType? type;

  /// Extra tokens that should match this supplier in free-form descriptions.
  final List<String> aliases;

  /// Optional hint keywords shared with the AI categoriser to boost confidence.
  final List<String> hints;

  /// Normalised supplier token for quick lookups.
  String get normalizedName => supplierName.trim().toLowerCase();

  /// Normalised aliases (lowercase, trimmed, empty entries removed).
  List<String> get normalizedAliases => aliases
      .map((alias) => alias.trim().toLowerCase())
      .where((alias) => alias.isNotEmpty)
      .toList();

  /// All tokens that should trigger this mapping when present in text.
  List<String> get matchTokens => {
        normalizedName,
        ...normalizedAliases,
      }.where((token) => token.isNotEmpty).toList();

  /// Hint keywords shared with the AI categoriser (always lowercase).
  List<String> get categorizationHints => hints
      .map((hint) => hint.trim().toLowerCase())
      .where((hint) => hint.isNotEmpty)
      .toList();

  /// Serialises this mapping into the persisted JSON structure.
  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'supplier': supplierName,
      'type': SupplierSpendTypeHelper.storageValue(type),
    };
    if (aliases.isNotEmpty) {
      payload['aliases'] = aliases;
    }
    if (hints.isNotEmpty) {
      payload['hints'] = hints;
    }
    return payload;
  }

  /// Creates a mapping from a JSON object (accepts `supplier` or `name` keys).
  factory SupplierSpendTypeMapping.fromJson(Map<String, dynamic> json) {
    final supplier = (json['supplier'] ?? json['name'])?.toString().trim();
    final typeValue = json['type']?.toString();

    if (supplier == null || supplier.isEmpty) {
      throw FormatException('Supplier name missing in mapping: $json');
    }
    final spendType = SupplierSpendTypeHelper.fromString(typeValue);
    if (spendType == null) {
      throw FormatException(
          'Unsupported spend type "$typeValue" for $supplier');
    }

    return SupplierSpendTypeMapping(
      supplierName: supplier,
      type: spendType,
      aliases: _parseStringList(json['aliases'] ?? json['alias']),
      hints: _parseStringList(json['hints'] ?? json['hint']),
    );
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw == null) {
      return const [];
    }
    if (raw is List) {
      return raw
          .map((entry) => entry.toString())
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      return raw
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    return const [];
  }
}

/// Default supplier spend mappings used for seeding new company files.
const List<SupplierSpendTypeMapping> kDefaultSupplierSpendTypeMappings = [
  SupplierSpendTypeMapping(
    supplierName: 'Bunnings',
    type: SupplierSpendType.oneTime,
  ),
  SupplierSpendTypeMapping(
    supplierName: 'Rent',
    type: SupplierSpendType.fixed,
  ),
  SupplierSpendTypeMapping(
    supplierName: 'Oji',
    type: SupplierSpendType.variable,
  ),
];

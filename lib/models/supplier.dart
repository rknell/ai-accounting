import 'package:json_annotation/json_annotation.dart';

part 'supplier.g.dart';

/// 🏪 **SUPPLIER MODEL**: Represents a business supplier with supplies info and optional account code
///
/// This model handles the supplier_list.json format with:
/// - name: Clean, friendly supplier name (without location codes)
/// - supplies: Description of what the supplier provides
/// - account: Optional fixed numeric account code for categorization
@JsonSerializable()
class SupplierModel {
  /// Clean, friendly name of the supplier
  /// Excludes location information or store codes
  /// Example: "GitHub" instead of "Github, Inc." or "Sp Github Payment"
  final String name;

  /// Description of what the supplier primarily supplies
  /// This is interpretable data, not a fixed account code
  /// Example: "Software development tools and services"
  final String supplies;

  /// Optional fixed numeric account code
  /// Used for automatic transaction categorization
  /// Example: "401" for software services
  final String? account;

  /// Creates a new supplier with required name and supplies info
  const SupplierModel({
    required this.name,
    required this.supplies,
    this.account,
  });

  /// Create from JSON map
  factory SupplierModel.fromJson(Map<String, dynamic> json) =>
      _$SupplierModelFromJson(json);

  /// Convert to JSON map
  Map<String, dynamic> toJson() => _$SupplierModelToJson(this);

  /// Create a copy with updated fields
  SupplierModel copyWith({
    String? name,
    String? supplies,
    String? account,
  }) {
    return SupplierModel(
      name: name ?? this.name,
      supplies: supplies ?? this.supplies,
      account: account ?? this.account,
    );
  }

  /// Check if supplier has an account code assigned
  bool get hasAccountCode => account != null && account!.isNotEmpty;

  /// Get display string for logging/debugging
  String get displayString =>
      '$name: $supplies${hasAccountCode ? ' (Account: $account)' : ''}';

  @override
  String toString() =>
      'SupplierModel(name: $name, supplies: $supplies, account: $account)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SupplierModel &&
        other.name == name &&
        other.supplies == supplies &&
        other.account == account;
  }

  @override
  int get hashCode => Object.hash(name, supplies, account);
}

/// 🏪 **SUPPLIER LIST HELPER**: Utilities for working with supplier lists
class SupplierListHelper {
  /// Load suppliers from JSON list
  static List<SupplierModel> fromJsonList(List<dynamic> jsonList) {
    return jsonList
        .map((json) => SupplierModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Convert suppliers to JSON list
  static List<Map<String, dynamic>> toJsonList(List<SupplierModel> suppliers) {
    return suppliers.map((supplier) => supplier.toJson()).toList();
  }

  /// Find supplier by name (case-insensitive fuzzy match)
  static SupplierModel? findSupplierByName(
      List<SupplierModel> suppliers, String name) {
    final lowerName = name.toLowerCase().trim();

    // Exact match first
    for (final supplier in suppliers) {
      if (supplier.name.toLowerCase() == lowerName) {
        return supplier;
      }
    }

    // Fuzzy match - contains check
    for (final supplier in suppliers) {
      final supplierName = supplier.name.toLowerCase();
      if (supplierName.contains(lowerName) ||
          lowerName.contains(supplierName)) {
        return supplier;
      }
    }

    return null;
  }

  /// Sort suppliers alphabetically by name
  static List<SupplierModel> sortByName(List<SupplierModel> suppliers) {
    final sorted = List<SupplierModel>.from(suppliers);
    sorted.sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  /// Get suppliers with account codes
  static List<SupplierModel> getSuppliersWithAccounts(
      List<SupplierModel> suppliers) {
    return suppliers.where((supplier) => supplier.hasAccountCode).toList();
  }

  /// Get suppliers without account codes
  static List<SupplierModel> getSuppliersWithoutAccounts(
      List<SupplierModel> suppliers) {
    return suppliers.where((supplier) => !supplier.hasAccountCode).toList();
  }
}

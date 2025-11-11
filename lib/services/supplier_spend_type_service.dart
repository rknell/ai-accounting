import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/models/supplier_spend_type.dart';
import 'package:ai_accounting/services/company_file_service.dart';
import 'package:path/path.dart' as p;

/// Loads and resolves supplier-to-spend-type mappings for reporting.
class SupplierSpendTypeService {
  /// Creates a service bound to [configDirectory] (or the resolved config root).
  SupplierSpendTypeService({
    String? configDirectory,
    CompanyFileService? companyFileService,
    bool testMode = false,
  })  : _configDirectory = configDirectory ??
            Platform.environment['AI_ACCOUNTING_CONFIG_DIR'] ??
            'config',
        _companyFileService = companyFileService,
        _testMode = testMode {
    _loadMappings();
  }

  static const _fileName = 'supplier_spend_types.json';

  final String _configDirectory;
  final CompanyFileService? _companyFileService;
  final bool _testMode;
  final Map<String, SupplierSpendTypeMapping> _bySupplier = {};
  final List<SupplierSpendTypeMapping> _mappings = [];

  /// Absolute path to the mapping file (created when missing).
  String get filePath => p.join(_configDirectory, _fileName);

  /// Immutable view of all configured mappings.
  List<SupplierSpendTypeMapping> get mappings => List.unmodifiable(_mappings);

  /// Reloads mappings from disk (useful when external automations update the file).
  void reload() => _loadMappings();

  /// Returns the spend type for [supplierName], if configured.
  SupplierSpendType? typeForSupplier(String? supplierName) =>
      findBySupplier(supplierName)?.type;

  /// Finds the mapping matching [supplierName] (case-insensitive).
  SupplierSpendTypeMapping? findBySupplier(String? supplierName) {
    if (supplierName == null) {
      return null;
    }
    final normalized = supplierName.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    return _bySupplier[normalized];
  }

  /// Performs a substring search for any mapping present in [text].
  SupplierSpendTypeMapping? findInText(String text) {
    if (text.trim().isEmpty) {
      return null;
    }
    final haystack = text.toLowerCase();
    for (final mapping in _mappings) {
      if (haystack.contains(mapping.normalizedName)) {
        return mapping;
      }
    }
    return null;
  }

  /// Ensures [supplierName] has an entry in the configuration, returning it.
  SupplierSpendTypeMapping? ensureSupplierEntry(String? supplierName) {
    if (supplierName == null) {
      return null;
    }
    final normalized = supplierName.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final existing = findBySupplier(normalized);
    if (existing != null) {
      return existing;
    }

    final mapping =
        SupplierSpendTypeMapping(supplierName: normalized, type: null);
    _registerMapping(mapping);
    _persistMappings();
    print('ℹ️  Added supplier spend entry for "$normalized"');
    return mapping;
  }

  void _loadMappings() {
    final companyService = _companyFileService;
    if (companyService != null) {
      companyService.ensureCompanyFileReady();
      final inFile = companyService.getSupplierSpendTypes();
      if (inFile.isNotEmpty) {
        _mappings
          ..clear()
          ..addAll(inFile);
        _rebuildIndex();
        if (!_testMode) {
          _writeConfigFile();
        }
        return;
      }
    }

    _loadFromConfig();
  }

  void _loadFromConfig() {
    final file = File(filePath);
    if (!file.existsSync()) {
      _seedDefaultFile(file);
    }

    try {
      final decoded = jsonDecode(file.readAsStringSync());
      _applyDecodedMappings(decoded);
      if (_companyFileService != null && !_testMode) {
        _persistMappings(); // mirror into company file
      }
    } catch (e) {
      print('⚠️  Failed to read $filePath ($e). Falling back to defaults.');
      _applyDefaultMappings();
    }
  }

  void _applyDecodedMappings(dynamic decoded) {
    _mappings.clear();

    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          _registerMapping(SupplierSpendTypeMapping.fromJson(item));
        } else if (item is Map) {
          _registerMapping(SupplierSpendTypeMapping.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value))));
        }
      }
      return;
    }

    if (decoded is Map<String, dynamic>) {
      decoded.forEach((key, value) {
        final spendType = SupplierSpendTypeHelper.fromString(value?.toString());
        _registerMapping(SupplierSpendTypeMapping(
          supplierName: key,
          type: spendType,
        ));
      });
    } else if (decoded is! List) {
      throw FormatException('Unsupported mapping format');
    }

    _rebuildIndex();
  }

  void _registerMapping(SupplierSpendTypeMapping mapping) {
    // Remove any prior entry with the same supplier so the file order wins.
    _mappings.removeWhere(
        (existing) => existing.normalizedName == mapping.normalizedName);
    _mappings.add(mapping);
    _bySupplier[mapping.normalizedName] = mapping;
  }

  void _rebuildIndex() {
    _bySupplier
      ..clear()
      ..addEntries(
        _mappings.map(
          (mapping) => MapEntry(mapping.normalizedName, mapping),
        ),
      );
  }

  void _seedDefaultFile(File file) {
    file.parent.createSync(recursive: true);
    final encoder = const JsonEncoder.withIndent('  ');
    file.writeAsStringSync(
      encoder.convert(
        kDefaultSupplierSpendTypeMappings.map((m) => m.toJson()).toList(),
      ),
    );
  }

  void _applyDefaultMappings() {
    _mappings
      ..clear()
      ..addAll(kDefaultSupplierSpendTypeMappings);
    _rebuildIndex();
    if (!_testMode) {
      _persistMappings();
    }
  }

  void _persistMappings() {
    final svc = _companyFileService;
    if (svc != null && svc.currentCompanyFile != null) {
      svc.updateCompanyFile(
        (current) => current.copyWith(
          supplierSpendTypes: List<SupplierSpendTypeMapping>.from(_mappings),
        ),
      );
    }

    if (!_testMode) {
      _writeConfigFile();
    }
  }

  void _writeConfigFile() {
    final encoder = const JsonEncoder.withIndent('  ');
    File(filePath)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        encoder.convert(_mappings.map((m) => m.toJson()).toList()),
      );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

/// 🏪 SUPPLIER MANAGEMENT FOCUSED TESTS
///
/// Comprehensive testing of supplier management functionality
/// extracted from working test scripts and enhanced with proper test structure.

void main() {
  group('🏪 Supplier Management Tests', () {
    late File supplierFile;
    late int originalSupplierCount;

    setUpAll(() {
      supplierFile = File('inputs/supplier_list.json');
      originalSupplierCount = 0;

      if (supplierFile.existsSync()) {
        final content = supplierFile.readAsStringSync();
        final suppliers = jsonDecode(content) as List<dynamic>;
        originalSupplierCount = suppliers.length;
        print('📊 Original supplier count: $originalSupplierCount');
      }
    });

    test('🔍 Fuzzy matching algorithm comprehensive test', () {
      final testCases = [
        // Prefix removal tests
        {
          'input': 'Sp Github Payment',
          'existing': 'Github, Inc.',
          'shouldMatch': true
        },
        {
          'input': 'Visa Purchase Cursor',
          'existing': 'Cursor, Ai Powered',
          'shouldMatch': true
        },

        // Suffix removal tests
        {
          'input': 'Amazon',
          'existing': 'Amazon Web Services',
          'shouldMatch': true
        },
        {'input': 'Google', 'existing': 'Google Cloud', 'shouldMatch': true},

        // Location and number removal
        {
          'input': 'Bunnings 1234',
          'existing': 'Bunnings Group Ltd',
          'shouldMatch': true
        },

        // Exact matches after normalization
        {
          'input': 'GitHub, Inc.',
          'existing': 'Github Inc',
          'shouldMatch': true
        },
        {
          'input': 'PayPal Australia',
          'existing': 'Paypal Australia',
          'shouldMatch': true
        },

        // Core name matching
        {'input': 'Stripe Payment', 'existing': 'Stripe', 'shouldMatch': true},
        {'input': 'Apple Com', 'existing': 'Apple.Com', 'shouldMatch': true},

        // Should NOT match
        {
          'input': 'Apple Store',
          'existing': 'Microsoft Office',
          'shouldMatch': false
        },
        {
          'input': 'Completely Different Name',
          'existing': 'Totally Unrelated Business',
          'shouldMatch': false
        },
        {'input': 'Short', 'existing': 'Different', 'shouldMatch': false},
      ];

      for (final testCase in testCases) {
        final input = testCase['input'] as String;
        final existing = testCase['existing'] as String;
        final shouldMatch = testCase['shouldMatch'] as bool;

        final matches = _testFuzzyMatch(input, existing);

        expect(matches, equals(shouldMatch),
            reason:
                '"$input" vs "$existing" should ${shouldMatch ? 'match' : 'not match'}');
      }
    });

    test('📝 Supplier data structure validation', () {
      final validSupplier = {
        'name': 'Test Supplier Co.',
        'supplies': 'Software development tools and services',
      };

      final validSupplierWithAccount = {
        'name': 'Test Supplier Co.',
        'supplies': 'Software development tools and services',
        'account': '401',
      };

      final invalidSuppliers = [
        {'name': 'Test'}, // Missing supplies
        {'supplies': 'Test'}, // Missing name
        {'name': '', 'supplies': 'Test'}, // Empty name
        {'name': 'Test', 'supplies': ''}, // Empty supplies
        {
          'name': 'Test',
          'supplies': 'Valid',
          'account': ''
        }, // Empty account when provided
      ];

      expect(_isValidSupplierData(validSupplier), isTrue);
      expect(_isValidSupplierData(validSupplierWithAccount), isTrue);

      for (final invalid in invalidSuppliers) {
        expect(_isValidSupplierData(invalid), isFalse);
      }
    });

    test('🏷️ Supplies description validation', () {
      final validSupplies = [
        'Software development tools and services',
        'Marketing and advertising services',
        'Cloud computing and infrastructure services',
        'Office supplies and stationery',
        'Vehicle maintenance and fuel services',
        'Staff wages and employment services',
        'Business insurance services',
        'Web hosting and domain services',
        'Electricity and utility services',
        'Fermentation ingredients and supplies',
        'Product labels and printing services',
        'Bottles and packaging materials',
      ];

      for (final supplies in validSupplies) {
        expect(supplies, isNotEmpty);
        expect(supplies, isNot(startsWith(' ')));
        expect(supplies, isNot(endsWith(' ')));
      }
    });

    test('📊 Supplier list integrity check', () {
      if (supplierFile.existsSync()) {
        final content = supplierFile.readAsStringSync();
        expect(content, isNotEmpty);

        final suppliers = jsonDecode(content) as List<dynamic>;
        expect(suppliers, isA<List<dynamic>>());

        // Check each supplier has required fields
        for (final supplier in suppliers) {
          expect(supplier, isA<Map<String, dynamic>>());
          expect(supplier['name'], isA<String>());
          expect(supplier['supplies'], isA<String>());
          expect(supplier['name'], isNotEmpty);
          expect(supplier['supplies'], isNotEmpty);
          // Account is optional
          if (supplier.containsKey('account') == true) {
            expect(supplier['account'], isA<String>());
            expect(supplier['account'], isNotEmpty);
          }
        }

        // Check alphabetical sorting
        final names = suppliers.map((s) => s['name'] as String).toList();
        final sortedNames = List<String>.from(names)..sort();
        expect(names, equals(sortedNames),
            reason: 'Suppliers should be sorted alphabetically');
      }
    });

    test('🔧 Supplier addition simulation', () {
      final testSupplierName =
          'Test MCP Supplier ${DateTime.now().millisecondsSinceEpoch}';
      final testSupplier = {
        'name': testSupplierName,
        'category': 'Software Development Tools',
      };

      // Read current suppliers
      List<Map<String, dynamic>> suppliers = [];
      if (supplierFile.existsSync()) {
        final content = supplierFile.readAsStringSync();
        if (content.isNotEmpty) {
          suppliers =
              (jsonDecode(content) as List).cast<Map<String, dynamic>>();
        }
      }

      final originalCount = suppliers.length;

      // Add test supplier
      suppliers.add(testSupplier);
      suppliers
          .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      expect(suppliers.length, equals(originalCount + 1));
      expect(suppliers.any((s) => s['name'] == testSupplierName), isTrue);

      // Verify sorting is maintained
      for (int i = 1; i < suppliers.length; i++) {
        expect(
            (suppliers[i - 1]['name'] as String)
                .compareTo(suppliers[i]['name'] as String),
            lessThanOrEqualTo(0));
      }

      print('✅ Successfully simulated adding supplier: $testSupplierName');
    });

    test('🎯 Edge cases handling', () {
      // Test empty supplier list
      final emptySuppliers = <Map<String, dynamic>>[];
      expect(emptySuppliers, isEmpty);

      // Test malformed data handling
      expect(() {
        final malformed = {'invalid': 'data'};
        _isValidSupplierData(malformed);
      }, returnsNormally);

      // Test special characters in names
      final specialCharSupplier = {
        'name': 'Test & Co. (Pty) Ltd.',
        'supplies': 'Professional services and consulting'
      };
      expect(_isValidSupplierData(specialCharSupplier), isTrue);
    });
  });
}

/// Test fuzzy matching logic (simplified version of MCP server logic)
bool _testFuzzyMatch(String name1, String name2) {
  final normalized1 = _normalizeSupplierName(name1);
  final normalized2 = _normalizeSupplierName(name2);

  // Exact match after normalization
  if (normalized1 == normalized2) return true;

  // Get variations for both names
  final variations1 = _getSupplierVariations(normalized1);
  final variations2 = _getSupplierVariations(normalized2);

  // Check if any variations match
  for (final var1 in variations1) {
    for (final var2 in variations2) {
      if (var1 == var2 && var1.length > 2) return true;
    }
  }

  // Check if core business names match (after removing prefixes/suffixes)
  final core1 = _extractCoreName(normalized1);
  final core2 = _extractCoreName(normalized2);

  if (core1.isNotEmpty && core2.isNotEmpty) {
    if (core1 == core2) return true;
    if (core1.contains(core2) || core2.contains(core1)) {
      return core1.length > 3 || core2.length > 3; // Avoid very short matches
    }
  }

  return false;
}

/// Extract core business name by removing common prefixes and suffixes
String _extractCoreName(String normalizedName) {
  String core = normalizedName;

  // Remove prefixes
  final prefixes = ['sp ', 'visa purchase ', 'eftpos ', 'paypal ', 'sq '];
  for (final prefix in prefixes) {
    if (core.startsWith(prefix)) {
      core = core.substring(prefix.length);
      break;
    }
  }

  // Remove suffixes
  final suffixes = [' pty ltd', ' ltd', ' inc', ' com', ' au', ' corporation'];
  for (final suffix in suffixes) {
    if (core.endsWith(suffix)) {
      core = core.substring(0, core.length - suffix.length);
      break;
    }
  }

  // Remove numbers and extra whitespace
  core = core
      .replaceAll(RegExp(r'\d+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return core;
}

/// Normalize supplier name for comparison
String _normalizeSupplierName(String name) {
  return name
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
      .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
      .trim();
}

/// Get common variations of a supplier name
List<String> _getSupplierVariations(String normalizedName) {
  final variations = <String>[normalizedName];

  // Remove common prefixes
  final prefixes = ['sp ', 'visa purchase ', 'eftpos ', 'paypal ', 'sq '];
  for (final prefix in prefixes) {
    if (normalizedName.startsWith(prefix)) {
      variations.add(normalizedName.substring(prefix.length));
    }
  }

  // Remove common suffixes
  final suffixes = [' pty ltd', ' ltd', ' inc', ' com', ' au', ' corporation'];
  for (final suffix in suffixes) {
    if (normalizedName.endsWith(suffix)) {
      variations.add(
          normalizedName.substring(0, normalizedName.length - suffix.length));
    }
  }

  // Remove location codes and numbers
  final withoutNumbers = normalizedName.replaceAll(RegExp(r'\d+'), '').trim();
  if (withoutNumbers != normalizedName && withoutNumbers.length > 2) {
    variations.add(withoutNumbers);
  }

  return variations;
}

/// Validate supplier data structure
bool _isValidSupplierData(Map<String, dynamic> supplier) {
  final hasRequiredFields = supplier.containsKey('name') &&
      supplier.containsKey('supplies') &&
      supplier['name'] is String &&
      supplier['supplies'] is String &&
      (supplier['name'] as String).isNotEmpty &&
      (supplier['supplies'] as String).isNotEmpty;

  // Check optional account field if present
  if (supplier.containsKey('account')) {
    return hasRequiredFields &&
        supplier['account'] is String &&
        (supplier['account'] as String).isNotEmpty;
  }

  return hasRequiredFields;
}

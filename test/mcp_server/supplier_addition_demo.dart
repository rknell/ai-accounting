import 'dart:convert';
import 'dart:io';

/// Test adding a new supplier to verify the functionality
void main() async {
  print('🧪 Testing Add New Supplier...');

  final supplierFile = File('inputs/supplier_list.json');

  // Read current count
  int originalCount = 0;
  if (supplierFile.existsSync()) {
    final content = supplierFile.readAsStringSync();
    final suppliers = jsonDecode(content) as List<dynamic>;
    originalCount = suppliers.length;
    print('Original supplier count: $originalCount');
  }

  // Simulate adding a new supplier (as the MCP server would)
  try {
    List<Map<String, dynamic>> suppliers = [];

    if (supplierFile.existsSync()) {
      final jsonString = supplierFile.readAsStringSync();
      if (jsonString.isNotEmpty) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        suppliers = jsonList.cast<Map<String, dynamic>>();
      }
    }

    // Test data
    final newSupplier = {
      'name': 'OpenAI API Services',
      'supplies': 'AI API services and software development tools',
      'account': '401',
    };

    // Check if supplier already exists
    bool exists = false;
    for (final supplier in suppliers) {
      if ((supplier['name'] as String).toLowerCase() ==
          newSupplier['name']!.toLowerCase()) {
        exists = true;
        break;
      }
    }

    if (!exists) {
      // Add new supplier
      suppliers.add(newSupplier);

      // Sort alphabetically
      suppliers
          .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      // Save with pretty formatting
      const encoder = JsonEncoder.withIndent('  ');
      final prettyJsonString = encoder.convert(suppliers);
      supplierFile.writeAsStringSync(prettyJsonString);

      print(
          '✅ Added new supplier: ${newSupplier['name']} (${newSupplier['supplies']}${newSupplier.containsKey('account') ? ', Account: ${newSupplier['account']}' : ''})');
      print('✅ New supplier count: ${suppliers.length}');

      // Verify it was added correctly
      final verifyContent = supplierFile.readAsStringSync();
      if (verifyContent.contains(newSupplier['name']!)) {
        print('✅ Verification successful: Supplier found in file');
      } else {
        print('❌ Verification failed: Supplier not found in file');
      }
    } else {
      print('ℹ️  Supplier already exists: ${newSupplier['name']}');
    }
  } catch (e) {
    print('❌ Error adding supplier: $e');
  }

  print('\n🏆 Supplier addition test completed!');
}

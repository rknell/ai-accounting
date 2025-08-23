/// 🧪 **CRUD OPERATIONS TEST**: Test new supplier and accounting rules CRUD functionality
///
/// This test verifies that all CRUD operations work correctly for both supplier management
/// and accounting rules management in the MCP server.
library;

import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import '../../mcp/mcp_server_accountant.dart';

/// Test helper to create isolated test directories
void setupTestEnvironment() {
  final testDir = Directory('test_data');
  if (testDir.existsSync()) {
    testDir.deleteSync(recursive: true);
  }
  testDir.createSync();

  final inputsDir = Directory('test_data/inputs');
  inputsDir.createSync();

  final dataDir = Directory('test_data/data');
  dataDir.createSync();
}

void cleanupTestEnvironment() {
  final testDir = Directory('test_data');
  if (testDir.existsSync()) {
    testDir.deleteSync(recursive: true);
  }
}

void main() {
  group('🛡️ REGRESSION: MCP Server CRUD Operations', () {
    late AccountantMCPServer server;

    setUp(() async {
      setupTestEnvironment();

      server = AccountantMCPServer(
        enableDebugLogging: true,
        inputsPath: 'test_data/inputs',
        dataPath: 'test_data/data',
        logger: (level, message, [data]) {
          print('[$level] $message${data != null ? ': $data' : ''}');
        },
      );
      await server.initializeServer();
    });

    tearDown(() async {
      await server.shutdown();
      cleanupTestEnvironment();
    });

    group('🏪 Supplier CRUD Operations', () {
      test('🛡️ REGRESSION: Create, Read, Update, Delete supplier lifecycle',
          () async {
        // Test CREATE
        final createResult = await server.callTool('create_supplier', {
          'supplierName': 'Test Supplier Inc',
          'supplies': 'Testing services and quality assurance',
          'account': '301',
        });

        final createData = jsonDecode(createResult.content.first.text!);
        expect(createData['success'], isTrue);
        expect(createData['action'], equals('created'));
        expect(createData['supplier']['name'], equals('Test Supplier Inc'));

        // Test READ
        final readResult = await server.callTool('read_supplier', {
          'supplierName': 'Test Supplier Inc',
        });

        final readData = jsonDecode(readResult.content.first.text!);
        expect(readData['success'], isTrue);
        expect(readData['supplier']['name'], equals('Test Supplier Inc'));
        expect(readData['supplier']['supplies'],
            equals('Testing services and quality assurance'));

        // Test LIST
        final listResult = await server.callTool('list_suppliers', {});
        final listData = jsonDecode(listResult.content.first.text!);
        expect(listData['success'], isTrue);
        expect(listData['suppliers'], hasLength(1));

        // Test UPDATE
        final updateResult = await server.callTool('update_supplier', {
          'supplierName': 'Test Supplier Inc',
          'supplies': 'Updated testing services and quality assurance',
          'newSupplierName': 'Test Supplier LLC',
        });

        final updateData = jsonDecode(updateResult.content.first.text!);
        expect(updateData['success'], isTrue);
        expect(updateData['action'], equals('updated'));
        expect(updateData['supplier']['name'], equals('Test Supplier LLC'));
        expect(updateData['supplier']['supplies'],
            equals('Updated testing services and quality assurance'));

        // Test DELETE
        final deleteResult = await server.callTool('delete_supplier', {
          'supplierName': 'Test Supplier LLC',
          'confirmDelete': true,
        });

        final deleteData = jsonDecode(deleteResult.content.first.text!);
        expect(deleteData['success'], isTrue);
        expect(deleteData['action'], equals('deleted'));
        expect(
            deleteData['deletedSupplier']['name'], equals('Test Supplier LLC'));

        // Verify deletion - should return not found instead of throwing
        final notFoundResult = await server.callTool('read_supplier', {
          'supplierName': 'Test Supplier LLC',
        });

        final notFoundData = jsonDecode(notFoundResult.content.first.text!);
        expect(notFoundData['success'], isTrue);
        expect(notFoundData['found'], isFalse);
        expect(notFoundData['message'],
            contains('Supplier not found, web research suggested'));
      });

      test('🛡️ REGRESSION: Fuzzy matching works correctly', () async {
        // Create supplier
        await server.callTool('create_supplier', {
          'supplierName': 'GitHub, Inc.',
          'supplies': 'Software development platform',
        });

        // Test fuzzy matching on read
        final readResult = await server.callTool('read_supplier', {
          'supplierName': 'github inc',
          'exactMatch': false,
        });

        final readData = jsonDecode(readResult.content.first.text!);
        expect(readData['success'], isTrue);
        expect(readData['found'], isTrue);
        expect(readData['matchedName'], equals('GitHub, Inc.'));
        expect(readData['matchType'], equals('fuzzy'));
      });

      test('🛡️ REGRESSION: Non-existent supplier returns helpful message',
          () async {
        // Try to read a supplier that doesn't exist
        final readResult = await server.callTool('read_supplier', {
          'supplierName': 'Non Existent Supplier',
        });

        final readData = jsonDecode(readResult.content.first.text!);
        expect(readData['success'], isTrue);
        expect(readData['found'], isFalse);
        expect(readData['searchTerm'], equals('Non Existent Supplier'));
        expect(readData['message'],
            equals('Supplier not found, web research suggested'));
        expect(readData['suggestion'], contains('puppeteer_navigate'));
        expect(readData['suggestion'], contains('create_supplier'));
      });
    });

    group('📋 Accounting Rules CRUD Operations', () {
      test('🛡️ REGRESSION: Create, Read, Update, Delete rule lifecycle',
          () async {
        // Test CREATE
        final createResult = await server.callTool('create_accounting_rule', {
          'ruleName': 'Test Rule',
          'condition': 'contains test transaction',
          'action': 'categorize as test expense',
          'accountCode': '301',
          'priority': 7,
          'notes': 'This is a test rule for automated testing',
        });

        final createData = jsonDecode(createResult.content.first.text!);
        expect(createData['success'], isTrue);
        expect(createData['action'], equals('created'));
        expect(createData['rule']['name'], equals('Test Rule'));
        expect(createData['rule']['priority'], equals(7));

        // Test READ
        final readResult = await server.callTool('read_accounting_rule', {
          'ruleName': 'Test Rule',
        });

        final readData = jsonDecode(readResult.content.first.text!);
        expect(readData['success'], isTrue);
        expect(readData['rule']['name'], equals('Test Rule'));
        expect(
            readData['rule']['condition'], equals('contains test transaction'));
        expect(readData['rule']['priority'], equals(7));

        // Test LIST
        final listResult = await server.callTool('list_accounting_rules', {});
        final listData = jsonDecode(listResult.content.first.text!);
        expect(listData['success'], isTrue);
        expect(listData['rules'], hasLength(1));

        // Test UPDATE
        final updateResult = await server.callTool('update_accounting_rule', {
          'ruleName': 'Test Rule',
          'newRuleName': 'Updated Test Rule',
          'condition': 'contains updated test transaction',
          'priority': 9,
        });

        final updateData = jsonDecode(updateResult.content.first.text!);
        expect(updateData['success'], isTrue);
        expect(updateData['action'], equals('updated'));
        expect(updateData['rule']['name'], equals('Updated Test Rule'));
        expect(updateData['rule']['condition'],
            equals('contains updated test transaction'));
        expect(updateData['rule']['priority'], equals(9));

        // Test DELETE
        final deleteResult = await server.callTool('delete_accounting_rule', {
          'ruleName': 'Updated Test Rule',
          'confirmDelete': true,
        });

        final deleteData = jsonDecode(deleteResult.content.first.text!);
        expect(deleteData['success'], isTrue);
        expect(deleteData['action'], equals('deleted'));
        expect(deleteData['deletedRule']['name'], equals('Updated Test Rule'));

        // Verify deletion - check that rules list is empty
        final emptyListResult =
            await server.callTool('list_accounting_rules', {});
        final emptyListData = jsonDecode(emptyListResult.content.first.text!);
        expect(emptyListData['success'], isTrue);
        expect(emptyListData['rules'], hasLength(0));
      });

      test('🛡️ REGRESSION: Filtering and sorting works correctly', () async {
        // Create multiple rules
        await server.callTool('create_accounting_rule', {
          'ruleName': 'High Priority Rule',
          'condition': 'contains important',
          'action': 'categorize as priority expense',
          'accountCode': '301',
          'priority': 10,
        });

        await server.callTool('create_accounting_rule', {
          'ruleName': 'Low Priority Rule',
          'condition': 'contains minor',
          'action': 'categorize as minor expense',
          'accountCode': '321',
          'priority': 1,
        });

        // Test filtering by condition
        final filterResult = await server.callTool('list_accounting_rules', {
          'filterByCondition': 'important',
        });

        final filterData = jsonDecode(filterResult.content.first.text!);
        expect(filterData['success'], isTrue);
        expect(filterData['rules'], hasLength(1));
        expect(filterData['rules'][0]['name'], equals('High Priority Rule'));

        // Test sorting by priority (default - high to low)
        final sortResult = await server.callTool('list_accounting_rules', {
          'sortBy': 'priority',
        });

        final sortData = jsonDecode(sortResult.content.first.text!);
        expect(sortData['success'], isTrue);
        expect(sortData['rules'], hasLength(2));
        expect(sortData['rules'][0]['name'],
            equals('High Priority Rule')); // Priority 10
        expect(sortData['rules'][1]['name'],
            equals('Low Priority Rule')); // Priority 1
      });
    });

    group('🔄 Legacy Compatibility', () {
      test('🛡️ REGRESSION: Legacy tools still work', () async {
        // Test legacy add_accounting_rule
        final legacyRuleResult = await server.callTool('add_accounting_rule', {
          'ruleName': 'Legacy Test Rule',
          'condition': 'contains legacy',
          'action': 'categorize as legacy expense',
          'accountCode': '301',
        });

        final legacyRuleData = jsonDecode(legacyRuleResult.content.first.text!);
        expect(legacyRuleData['success'], isTrue);

        // Test legacy update_supplier_info
        final legacySupplierResult =
            await server.callTool('update_supplier_info', {
          'supplierName': 'Legacy Supplier',
          'supplies': 'Legacy testing services',
        });

        final legacySupplierData =
            jsonDecode(legacySupplierResult.content.first.text!);
        expect(legacySupplierData['success'], isTrue);
      });
    });

    group('🛡️ Security and Validation', () {
      test('🛡️ REGRESSION: Delete confirmation required', () async {
        // Create test data
        await server.callTool('create_supplier', {
          'supplierName': 'Test Supplier',
          'supplies': 'Test services',
        });

        // Try to delete without confirmation
        try {
          await server.callTool('delete_supplier', {
            'supplierName': 'Test Supplier',
            'confirmDelete': false,
          });
          fail('Should have thrown exception for missing confirmation');
        } catch (e) {
          expect(e.toString(), contains('confirmDelete=true'));
        }
      });

      test('🛡️ REGRESSION: Duplicate prevention works', () async {
        // Create supplier
        await server.callTool('create_supplier', {
          'supplierName': 'Duplicate Test',
          'supplies': 'Test services',
        });

        // Try to create duplicate
        try {
          await server.callTool('create_supplier', {
            'supplierName': 'Duplicate Test',
            'supplies': 'Different services',
          });
          fail('Should have thrown exception for duplicate supplier');
        } catch (e) {
          expect(e.toString(), contains('already exists'));
        }
      });
    });
  });
}

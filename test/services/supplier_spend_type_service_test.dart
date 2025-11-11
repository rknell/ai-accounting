import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/models/supplier_spend_type.dart';
import 'package:ai_accounting/services/supplier_spend_type_service.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('✅ FEATURE: SupplierSpendTypeService', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync();
    });

    tearDown(() {
      tempDir.delete(recursive: true);
    });

    test('seeds default file when mapping missing', () {
      final service = SupplierSpendTypeService(configDirectory: tempDir.path);

      expect(
          File(p.join(tempDir.path, 'supplier_spend_types.json')).existsSync(),
          isTrue);
      expect(service.mappings, isNotEmpty);
    });

    test('loads custom mapping and resolves lookups', () {
      final file = File(p.join(tempDir.path, 'supplier_spend_types.json'));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode([
        {'supplier': 'Acme Supplies', 'type': 'fixed'}
      ]));

      final service = SupplierSpendTypeService(configDirectory: tempDir.path);

      expect(service.typeForSupplier('acme supplies'),
          equals(SupplierSpendType.fixed));
      expect(
        service.findInText('Invoice ACME SUPPLIES LTD August'),
        isNotNull,
      );
    });
  });
}

import 'package:ai_accounting/models/supplier.dart';
import 'package:test/test.dart';

void main() {
  group('✅ FEATURE: Supplier upsert helper', () {
    test('adds new supplier and sorts by name', () {
      final initial = <SupplierModel>[
        const SupplierModel(name: 'GitHub, Inc.', supplies: 'Dev tools'),
        const SupplierModel(name: 'Stripe', supplies: 'Payments'),
      ];

      final result = SupplierListHelper.upsertSupplier(
        initial,
        const SupplierModel(name: 'Apple', supplies: 'Computers'),
      );

      expect(result.length, equals(3));
      expect(result.map((s) => s.name).toList(),
          equals(['Apple', 'GitHub, Inc.', 'Stripe']));
    });

    test('fuzzy match prevents duplicate and fills unknown supplies', () {
      final initial = <SupplierModel>[
        const SupplierModel(name: 'Amazon Web Services', supplies: 'Unknown'),
      ];

      final result = SupplierListHelper.upsertSupplier(
        initial,
        const SupplierModel(name: 'Amazon', supplies: 'Cloud infrastructure'),
        replaceExistingSupplies: false,
      );

      expect(result.length, equals(1));
      expect(result.first.name, equals('Amazon Web Services'));
      expect(result.first.supplies, equals('Cloud infrastructure'));
    });

    test('does not overwrite non-unknown supplies unless instructed', () {
      final initial = <SupplierModel>[
        const SupplierModel(name: 'Google Cloud', supplies: 'Cloud services'),
      ];

      final noReplace = SupplierListHelper.upsertSupplier(
        initial,
        const SupplierModel(name: 'Google', supplies: 'Search engine'),
        replaceExistingSupplies: false,
      );
      expect(noReplace.first.supplies, equals('Cloud services'));

      final replace = SupplierListHelper.upsertSupplier(
        initial,
        const SupplierModel(name: 'Google', supplies: 'Search engine'),
        replaceExistingSupplies: true,
      );
      expect(replace.first.supplies, equals('Search engine'));
    });
  });
}



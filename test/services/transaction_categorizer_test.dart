import 'package:ai_accounting/services/transaction_categorizer.dart';
import 'package:test/test.dart';

void main() {
  group('🛡️ REGRESSION: Income transaction categorisation', () {
    test('customer payments map to sales revenue account 100', () {
      final result = categorizeIncomeTransaction(
        supplierName: 'Acme Corp',
        suppliesDescription: 'Monthly customer payment',
      );

      expect(result.accountCode, equals('100'));
      expect(
        result.justification,
        contains('customer payment for products or services'),
      );
    });

    test('payment processing suppliers map to other income account 150', () {
      final result = categorizeIncomeTransaction(
        supplierName: 'Stripe',
        suppliesDescription: 'Card processing services',
      );

      expect(result.accountCode, equals('150'));
      expect(result.justification, contains('Processing income'));
    });
  });
}


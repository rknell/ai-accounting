import 'package:ai_accounting/utils/supplier_note_parser.dart';
import 'package:test/test.dart';

void main() {
  group('SupplierNoteParser', () {
    test('extracts supplier without confidence block', () {
      expect(
        SupplierNoteParser.extractSupplier('Supplier: ACME Manufacturing'),
        equals('ACME Manufacturing'),
      );
    });

    test('strips trailing confidence metadata', () {
      expect(
        SupplierNoteParser.extractSupplier(
            'Categorised by AI\nSupplier: Office Depot (confidence: 92%)'),
        equals('Office Depot'),
      );
    });

    test('returns null when no supplier marker present', () {
      expect(SupplierNoteParser.extractSupplier('No supplier here'), isNull);
    });
  });
}

import 'package:ai_accounting/services/report_generation_service.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:test/test.dart';

void main() {
  group('🛡️ REGRESSION: ReportGenerationService Integration Tests', () {
    late ReportGenerationService reportService;
    late Services services;

    setUp(() {
      // 🛡️ WARRIOR PRINCIPLE: NEVER TOUCH LIVE DATA IN TESTS!
      // Create isolated test service in TEST MODE
      services = Services(testMode: true);
      reportService = ReportGenerationService(services);

      // Clear only in-memory data, not files
      services.generalJournal.entries.clear();
    });

    test('🧪 TEST: generateReports handles empty data gracefully', () {
      // This test verifies that the new generateReports method doesn't crash
      // when there's no transaction data and provides appropriate feedback

      // 🛡️ SAFE TEST: Only use in-memory data, never touch files
      // Journal entries are already cleared in setUp()

      // This should not throw an exception and should handle the empty case
      expect(() => reportService.generateReports(), returnsNormally);

      print('✅ generateReports handled empty data correctly');
    });

    test(
        '🧪 TEST: generatePreviousQuarterReports method exists and is callable',
        () {
      // This test verifies that the new generatePreviousQuarterReports method
      // exists and can be called without throwing exceptions

      // 🛡️ SAFE TEST: Only use in-memory data, never touch files
      // Journal entries are already cleared in setUp()

      // This should not throw an exception
      expect(() => reportService.generatePreviousQuarterReports(),
          returnsNormally);

      print('✅ generatePreviousQuarterReports method works correctly');
    });

    test('🧪 TEST: ReportGenerationService has both report generation methods',
        () {
      // Verify that both methods exist on the service
      expect(reportService.generateReports, isA<Function>());
      expect(reportService.generatePreviousQuarterReports, isA<Function>());

      print('✅ Both report generation methods are available');
    });
  });
}

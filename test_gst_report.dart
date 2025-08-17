import 'package:ai_accounting/services/services.dart';
import 'package:ai_accounting/reports/gst_report.dart';

void main() {
  final services = Services();
  final gstReport = GSTReport(services);
  
  // Generate GST report for Q1 2025
  final startDate = DateTime(2025, 1, 1);
  final endDate = DateTime(2025, 3, 31);
  
  print('🧪 Testing GST report generation for Q1 2025...');
  final result = gstReport.generate(startDate, endDate);
  
  if (result) {
    print('✅ GST report generated successfully!');
    print('📁 Check data/gst_report_20250101_to_20250331.html');
  } else {
    print('❌ GST report generation failed');
  }
}

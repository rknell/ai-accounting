import 'package:ai_accounting/reports/reports.dart';
import 'package:ai_accounting/services/services.dart';

/// Service that generates financial reports from general journal data
class ReportsService {
  /// The services instance containing required services
  final Services services;

  /// Creates a new reports service
  ///
  /// @param services The services instance containing required services
  ReportsService(this.services);

  /// Generates a profit and loss report for a specified date range
  ///
  /// @param startDate The start date of the report period
  /// @param endDate The end date of the report period
  /// @return True if the report was successfully generated, false otherwise
  bool generateProfitAndLossReport(DateTime startDate, DateTime endDate) {
    final report = ProfitAndLossReport(services);
    return report.generate(startDate, endDate);
  }

  /// Generates a balance sheet report as of a specified date
  ///
  /// @param asOfDate The date for which to generate the balance sheet
  /// @return True if the report was successfully generated, false otherwise
  bool generateBalanceSheet(DateTime asOfDate) {
    final report = BalanceSheetReport(services);
    return report.generate(asOfDate);
  }

  /// Generates a GST report for a specified date range
  ///
  /// @param startDate The start date of the report period
  /// @param endDate The end date of the report period
  /// @return True if the report was successfully generated, false otherwise
  bool generateGSTReport(DateTime startDate, DateTime endDate) {
    final report = GSTReport(services);
    return report.generate(startDate, endDate);
  }

  /// Generates a report wrapper HTML file that provides navigation between all available reports
  ///
  /// @return True if the wrapper was successfully generated, false otherwise
  bool generateReportWrapper() {
    final wrapper = ReportWrapper(services);
    return wrapper.generateWrapper();
  }
}

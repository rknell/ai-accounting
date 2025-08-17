import 'package:ai_accounting/services/bank_statement_service.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';
import 'package:ai_accounting/services/environment_service.dart';
import 'package:ai_accounting/services/general_journal_service.dart';
import 'package:ai_accounting/services/report_generation_service.dart';
import 'package:ai_accounting/services/reports.dart';
import 'package:get_it/get_it.dart';

/// Services class that acts as a gateway to access all application services
///
/// This class provides a centralized access point to all services in the application,
/// making it easier to access services from anywhere in the codebase without
/// directly depending on GetIt throughout the application.
class Services {
  /// 🛡️ TEST MODE: Prevents file operations when true
  final bool _testMode;

  /// Constructor with optional test mode
  Services({bool testMode = false}) : _testMode = testMode;

  /// Private instance of the ChartOfAccountsService
  ChartOfAccountsService? _chartOfAccounts;

  /// Private instance of the GeneralJournalService
  GeneralJournalService? _generalJournal;

  /// Private instance of the BankStatementService
  BankStatementService? _bankStatement;

  /// Private instance of the ReportsService
  ReportsService? _reports;

  /// Private instance of the EnvironmentService
  EnvironmentService? _environment;

  /// Private instance of the ReportGenerationService
  ReportGenerationService? _reportGeneration;

  /// Instance of the ChartOfAccountsService
  ///
  /// This getter provides access to the chart of accounts functionality
  /// throughout the application. It is lazily instantiated when first accessed.
  ChartOfAccountsService get chartOfAccounts {
    return _chartOfAccounts ??= ChartOfAccountsService();
  }

  /// Instance of the GeneralJournalService
  ///
  /// Handles the creation, storage, and retrieval of general journal entries
  /// for accounting operations. Lazily instantiated when first accessed.
  GeneralJournalService get generalJournal {
    return _generalJournal ??= GeneralJournalService(testMode: _testMode);
  }

  /// Instance of the BankStatementService
  ///
  /// Responsible for loading, parsing, and processing bank statement files.
  /// Converts raw bank data into structured formats for accounting use.
  /// Lazily instantiated when first accessed.
  BankStatementService get bankStatement {
    return _bankStatement ??= BankStatementService();
  }

  /// Instance of the ReportsService
  ///
  /// Generates financial reports such as profit and loss statements,
  /// balance sheets, and GST reports. Lazily instantiated when first accessed.
  ReportsService get reports {
    return _reports ??= ReportsService(this);
  }

  /// Instance of the EnvironmentService
  ///
  /// Provides access to environment variables and configuration settings.
  /// Used for accessing account codes and other environment-specific values.
  /// Lazily instantiated when first accessed.
  EnvironmentService get environment {
    return _environment ??= EnvironmentService();
  }

  /// Instance of the ReportGenerationService
  ///
  /// Handles the generation of all financial reports including profit and loss,
  /// balance sheet, GST reports, and backup of input files.
  /// Lazily instantiated when first accessed.
  ReportGenerationService get reportGeneration {
    return _reportGeneration ??= ReportGenerationService(this);
  }
}

/// Global accessor for the Services instance
///
/// This getter provides a singleton instance of the Services class,
/// registering it with GetIt if it hasn't been registered yet.
/// This allows for consistent access to services throughout the application.
Services get services {
  if (GetIt.instance.isRegistered<Services>() == false) {
    GetIt.instance.registerSingleton<Services>(Services());
  }
  return GetIt.instance.get<Services>();
}

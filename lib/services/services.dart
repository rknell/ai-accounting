import 'package:ai_accounting/services/account_code_service.dart';
import 'package:ai_accounting/services/bank_statement_service.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';
import 'package:ai_accounting/services/deepseek_client.dart';
import 'package:ai_accounting/services/general_journal_service.dart';
import 'package:ai_accounting/services/reports.dart';
import 'package:get_it/get_it.dart';

/// Services class that acts as a gateway to access all application services
///
/// This class provides a centralized access point to all services in the application,
/// making it easier to access services from anywhere in the codebase without
/// directly depending on GetIt throughout the application.
class Services {
  /// Private instance of the ChartOfAccountsService
  ChartOfAccountsService? _chartOfAccounts;

  /// Private instance of the DeepseekClient
  DeepseekClient? _deepseekClient;

  /// Private instance of the AccountCodeService
  AccountCodeService? _accountCodes;

  /// Private instance of the GeneralJournalService
  GeneralJournalService? _generalJournal;

  /// Private instance of the BankStatementService
  BankStatementService? _bankStatement;

  /// Private instance of the ReportsService
  ReportsService? _reports;

  /// Instance of the ChartOfAccountsService
  ///
  /// This getter provides access to the chart of accounts functionality
  /// throughout the application. It is lazily instantiated when first accessed.
  ChartOfAccountsService get chartOfAccounts {
    return _chartOfAccounts ??= ChartOfAccountsService();
  }

  /// Instance of the DeepseekClient
  ///
  /// Provides access to the DeepSeek AI API for natural language processing
  /// and AI-assisted accounting operations. Lazily instantiated when first accessed.
  DeepseekClient get deepseekClient {
    return _deepseekClient ??= DeepseekClient();
  }

  /// Instance of the AccountCodeService
  ///
  /// Manages account codes and their mappings, providing functionality for
  /// categorizing transactions and determining appropriate account codes.
  /// Lazily instantiated when first accessed.
  AccountCodeService get accountCodes {
    return _accountCodes ??= AccountCodeService();
  }

  /// Instance of the GeneralJournalService
  ///
  /// Handles the creation, storage, and retrieval of general journal entries
  /// for accounting operations. Lazily instantiated when first accessed.
  GeneralJournalService get generalJournal {
    return _generalJournal ??= GeneralJournalService();
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

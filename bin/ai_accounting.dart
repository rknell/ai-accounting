import 'dart:convert';
import 'dart:io';

import 'package:ai_accounting/agents/accounting_agent_shell.dart';
import 'package:ai_accounting/exporters/general_journal_csv_exporter.dart';
import 'package:ai_accounting/exporters/transaction_summary_csv_exporter.dart';
import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/services/services.dart';
import 'package:path/path.dart' as path;

Future<void> main() async {
  final wizard = AccountingWizard();
  await wizard.run();
}

class AccountingWizard {
  AccountingWizard({Services? services}) : _services = services ?? Services();

  final Services _services;
  bool _shouldExit = false;

  Future<void> run() async {
    print('🧭 AI Accounting CLI');
    print('🎯 Central command interface for every tool under bin/.');

    while (!_shouldExit) {
      _printMenu();
      final choice = _prompt('\nSelect an option');
      switch (choice) {
        case '1':
          await _handleImportMenu();
          break;
        case '2':
          _warnIfMissingApiKey();
          await _runDartCommand(['run', 'bin/categorise_transactions.dart']);
          break;
        case '3':
          await _runDartCommand(['run', 'bin/generate_reports.dart']);
          break;
        case '4':
          _handleMappingManager();
          break;
        case '5':
          await _handleAiAccountantChat();
          break;
        case '6':
          await _handleGeneralJournalExport();
          break;
        case '7':
          await _handleTransactionSummaryExport();
          break;
        case '8':
        case 'q':
        case 'Q':
          _shouldExit = true;
          print('👋 Exiting wizard.');
          break;
        default:
          print('⚠️  Unknown option. Please choose 1-7 or q to quit.');
      }
    }
  }

  void _printMenu() {
    print('\n============ MENU ============');
    print('1) Import bank statements');
    print('2) Categorise uncategorised transactions');
    print('3) Generate financial reports');
    print('4) Manage bank statement filename mappings');
    print('5) Talk to the AI accountant');
    print('6) Export general journal to CSV');
    print('7) Export transaction summary (one row per entry)');
    print('8) Exit');
  }

  Future<void> _handleImportMenu() async {
    print('\n--- Import Options ---');
    print('1) Import all CSV files from inputs/');
    print('2) Import a specific CSV file now');
    print('3) Back');

    final choice = _prompt('Select import option');
    switch (choice) {
      case '1':
        await _runDartCommand(['run', 'bin/import_transactions.dart']);
        break;
      case '2':
        _listInputCsvFiles();
        final filePath = _prompt(
            'Enter absolute or relative path to the CSV file (or leave blank to cancel)',
            allowEmpty: true);
        if (filePath == null || filePath.isEmpty) {
          print('↩️  Import cancelled.');
          return;
        }

        final resolvedPath = path.normalize(path.absolute(filePath));
        final bankCode = _prompt(
            'Enter bank account code (optional – press Enter to auto-detect)',
            allowEmpty: true);

        final args = [
          'run',
          'bin/import_transactions.dart',
          '--file=$resolvedPath',
        ];
        if (bankCode != null && bankCode.trim().isNotEmpty) {
          args.add('--bank=${bankCode.trim()}');
        }

        await _runDartCommand(args);
        break;
      default:
        print('↩️  Returning to main menu.');
    }
  }

  Future<void> _handleAiAccountantChat() async {
    _warnIfMissingApiKey();
    final shell = AccountingAgentShell(
      config: AccountingAgentShellConfig(
        introTitle: '🤖 AI Accountant Chat: MCP-backed assistant',
        introDescription:
            'Chat with the accounting LLM to investigate, search, and recategorise transactions.',
        sessionIntro:
            '💬 Talk directly to the AI accountant.\nType \'exit\', \'quit\', or \'done\' to finish.',
        promptLabel: '💬 Enter your accounting request',
        specialInstructions: kAccountingAgentStandardSpecialInstructions,
        samplePrompts: const [
          'Find all MyPost transactions and make sure they use the Postage (COGS) account.',
          'Audit bank account 003 for uncategorised entries in the last 30 days.',
          'Review transactions currently coded to 999 and suggest better accounts.',
        ],
      ),
    );

    await shell.run();
  }

  Future<void> _runDartCommand(List<String> dartArgs) async {
    print('\n🔧 Running: dart ${dartArgs.join(' ')}');
    final process = await Process.start('dart', dartArgs);
    await Future.wait([
      stdout.addStream(process.stdout),
      stderr.addStream(process.stderr),
    ]);
    final exitCode = await process.exitCode;
    if (exitCode == 0) {
      print('✅ Command completed successfully.');
    } else {
      print('❌ Command exited with code $exitCode.');
    }
  }

  void _handleMappingManager() {
    final mappingFile = File(path.join(
        Directory.current.path, 'config', 'bank_account_mappings.json'));
    final currentMappings = _readMappings(mappingFile);

    if (currentMappings.isEmpty) {
      print('ℹ️  No mappings defined yet.');
    } else {
      print('\n📁 Existing mappings:');
      final sortedKeys = currentMappings.keys.toList()..sort();
      for (final key in sortedKeys) {
        print('  • $key -> ${currentMappings[key]}');
      }
    }

    final filename = _prompt(
        '\nEnter statement filename (without .csv) to map (blank to cancel)',
        allowEmpty: true);
    if (filename == null || filename.trim().isEmpty) {
      print('↩️  Mapping update cancelled.');
      return;
    }

    final sanitizedName =
        filename.trim().replaceAll(RegExp(r'\.csv$', caseSensitive: false), '');
    final bankCode =
        _prompt('Enter bank account code (001-099)', allowEmpty: false);
    if (bankCode == null ||
        bankCode.trim().isEmpty ||
        !_isValidBankCode(bankCode.trim())) {
      print(
          '⚠️  Invalid bank account code. Ensure it exists in inputs/accounts.json.');
      return;
    }

    currentMappings[sanitizedName] = bankCode.trim().padLeft(3, '0');

    final encoder = const JsonEncoder.withIndent('  ');
    final ordered = Map.fromEntries(currentMappings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key)));
    mappingFile
      ..createSync(recursive: true)
      ..writeAsStringSync(encoder.convert(ordered));

    print(
        '✅ Mapping saved: "$sanitizedName" ➜ ${currentMappings[sanitizedName]}');
  }

  Future<void> _handleGeneralJournalExport() async {
    final entries = _services.generalJournal.getAllEntries();
    if (entries.isEmpty) {
      print('⚠️  No journal entries available to export.');
      return;
    }

    final defaultPath = path.join(
      Directory.current.path,
      'data',
      'general_journal_export.csv',
    );

    print('\n--- General Journal Export ---');
    print('Default path: $defaultPath');
    final destination = _prompt(
      'Enter destination path (leave blank for default)',
      allowEmpty: true,
    );
    final resolvedPath = path.normalize(path.absolute(
      destination == null || destination.isEmpty ? defaultPath : destination,
    ));

    try {
      final exporter = GeneralJournalCsvExporter(_services);
      exporter.exportToFile(resolvedPath, entries: entries);
      final rowCount = entries.fold<int>(
        0,
        (sum, entry) => sum + entry.debits.length + entry.credits.length,
      );
      print('✅ Exported $rowCount journal rows to $resolvedPath');
    } catch (e) {
      print('❌ Failed to export general journal: $e');
    }
  }

  Future<void> _handleTransactionSummaryExport() async {
    final entries = _services.generalJournal.getAllEntries();
    if (entries.isEmpty) {
      print('⚠️  No journal entries available to export.');
      return;
    }

    final defaultPath = path.join(
      Directory.current.path,
      'data',
      'transaction_summary_export.csv',
    );

    print('\n--- Categorised Transaction Summary Export ---');
    print('Default path: $defaultPath');
    final destination = _prompt(
      'Enter destination path (leave blank for default)',
      allowEmpty: true,
    );
    final resolvedPath = path.normalize(path.absolute(
      destination == null || destination.isEmpty ? defaultPath : destination,
    ));

    try {
      final gstCode =
          Platform.environment['GST_CLEARING_ACCOUNT_CODE'] ?? '506';
      final exporter = TransactionSummaryCsvExporter(
        _services,
        gstClearingAccountCode: gstCode,
      );
      exporter.exportToFile(resolvedPath, entries: entries);
      print('✅ Exported ${entries.length} transactions to $resolvedPath');
    } catch (e) {
      print('❌ Failed to export transaction summary: $e');
    }
  }

  Map<String, String> _readMappings(File file) {
    if (!file.existsSync()) {
      return {};
    }

    try {
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) {
        return {};
      }
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      }
      return {};
    } catch (e) {
      print('⚠️  Failed to read ${file.path}: $e');
      return {};
    }
  }

  void _listInputCsvFiles() {
    final inputsDir = Directory(path.join(Directory.current.path, 'inputs'));
    if (!inputsDir.existsSync()) {
      return;
    }
    final csvFiles = inputsDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.csv'))
        .toList();

    if (csvFiles.isEmpty) {
      return;
    }

    print('\n📂 CSV files under inputs/:');
    for (final file in csvFiles) {
      print('  • ${path.basename(file.path)}');
    }
  }

  String? _prompt(String message, {bool allowEmpty = false}) {
    stdout.write('$message: ');
    final input = stdin.readLineSync();
    if ((input == null || input.trim().isEmpty) && !allowEmpty) {
      return _prompt(message, allowEmpty: allowEmpty);
    }
    return input?.trim();
  }

  bool _isValidBankCode(String code) {
    final normalized = code.padLeft(3, '0');
    final account = _services.chartOfAccounts.getAccount(normalized);
    return account != null && account.type == AccountType.bank;
  }

  void _warnIfMissingApiKey() {
    final env = Platform.environment;
    if (env['DEEPSEEK_API_KEY'] == null || env['DEEPSEEK_API_KEY']!.isEmpty) {
      print(
          '⚠️  DEEPSEEK_API_KEY is not set. Categorisation will fail until the key is exported.');
    }
  }
}

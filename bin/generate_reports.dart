import 'dart:io';

import 'package:ai_accounting/services/services.dart';

/// 📊 ELITE FINANCIAL REPORTS GENERATION SCRIPT
///
/// **MISSION**: Generate comprehensive financial reports for all quarters with transaction data.
/// Provides modular, focused report generation separate from transaction processing.
///
/// **ARCHITECTURE**:
/// - Uses existing ReportGenerationService for all report types
/// - Generates reports for all quarters that contain financial transactions
/// - Creates navigable HTML interface for easy report access
/// - Follows WARRIOR PROTOCOL: Single responsibility, comprehensive reporting
///
/// **GENERATED REPORTS**:
/// - Profit and Loss Report (per quarter)
/// - Balance Sheet (per quarter end)
/// - GST Report (per quarter)
/// - General Journal Report (per quarter)
/// - Ledger Report (per quarter)
/// - Report Wrapper (navigation interface)
///
/// **USAGE**: dart run bin/generate_reports.dart

Future<void> main() async {
  print('📊 Starting Financial Reports Generation...');

  try {
    // === INITIALIZATION PHASE ===
    print('📋 Step 1: Initializing services...');
    final services = Services();

    // Ensure general journal is loaded
    if (!services.generalJournal.loadEntries()) {
      print('⚠️  Failed to load general journal entries');
      print(
          '💡 Ensure data/general_journal.json exists and contains valid data');
      exit(1);
    }

    final totalEntries = services.generalJournal.getAllEntries().length;
    print('✅ Loaded $totalEntries general journal entries');

    if (totalEntries == 0) {
      print('⚠️  No transaction data found - no reports to generate');
      print('💡 NEXT STEPS:');
      print(
          '  📥 Run "dart run bin/import_transactions.dart" to import CSV files');
      print('  🤖 Run "dart run bin/run.dart" to categorize transactions');
      return;
    }

    // === STEP 2: GENERATE COMPREHENSIVE REPORTS ===
    print('\n📈 Step 2: Generating financial reports...');
    final startTime = DateTime.now();

    // Use the existing report generation service
    services.reportGeneration.generateReports();

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    // === STEP 3: REPORT STATISTICS ===
    print('\n🏆 REPORT GENERATION COMPLETE!');
    print('⚡ PERFORMANCE STATISTICS:');
    print('  🎯 Total transactions processed: $totalEntries');
    print(
        '  ⏱️  Generation time: ${duration.inSeconds}.${(duration.inMilliseconds % 1000).toString().padLeft(3, '0')}s');
    print('  📁 Reports saved to: data/ directory');

    // Get date range for reporting
    final entries = services.generalJournal.getAllEntries();
    if (entries.isNotEmpty) {
      final dates = entries.map((e) => e.date).toList()..sort();
      print(
          '  📅 Date range: ${dates.first.toIso8601String().substring(0, 10)} to ${dates.last.toIso8601String().substring(0, 10)}');
    }

    print('\n💡 NEXT STEPS:');
    print('  🌐 Open data/report_viewer.html to view all reports in browser');
    print('  📊 Individual reports are available in the data/ directory');
    print('  🔄 Re-run this script after importing new transactions');
  } catch (e, stackTrace) {
    print('\n❌ CRITICAL ERROR during report generation: $e');
    print('🔍 Stack trace: $stackTrace');

    // Provide helpful error context
    if (e.toString().contains('general_journal.json')) {
      print('\n💡 SOLUTION: Ensure general journal exists and is valid');
      print(
          '  📥 Run "dart run bin/import_transactions.dart" to create journal entries');
    }

    exit(1);
  }
}

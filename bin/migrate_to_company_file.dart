#!/usr/bin/env dart

import 'dart:io';

import 'package:ai_accounting/services/company_file_service.dart';

/// 🚀 **MIGRATION SCRIPT**: Demonstrates migration from individual files to CompanyFile
///
/// This script shows how to:
/// 1. Migrate existing individual files to a unified company file
/// 2. Save the company file
/// 3. Export back to individual files for backward compatibility
/// 4. Validate the migrated data
///
/// **USAGE:**
/// ```bash
/// dart bin/migrate_to_company_file.dart
/// ```
void main() async {
  print('🏢 Company File Migration Script');
  print('================================');
  print('');

  try {
    // Create the company file service
    final service = CompanyFileService(testMode: false);

    print('🔄 Starting migration from individual files...');
    print('');

    // Migrate from individual files
    final migrationSuccess = service.migrateFromIndividualFiles();

    if (!migrationSuccess) {
      print('❌ Migration failed. Please check the error messages above.');
      exit(1);
    }

    print('✅ Migration completed successfully!');
    print('');

    // Validate the migrated data
    print('🔍 Validating migrated data...');
    final validationErrors = service.validate();

    if (validationErrors.isNotEmpty) {
      print('⚠️  Validation warnings:');
      for (final error in validationErrors) {
        print('   - $error');
      }
      print('');
    } else {
      print('✅ All data validated successfully!');
      print('');
    }

    // Save the company file
    print('💾 Saving company file...');
    final saveSuccess = service.saveCompanyFile('data/company_file.json');

    if (!saveSuccess) {
      print('❌ Failed to save company file.');
      exit(1);
    }

    print('✅ Company file saved successfully!');
    print('');

    // Export back to individual files for backward compatibility
    print('📤 Exporting to individual files for backward compatibility...');
    final exportSuccess = service.exportToIndividualFiles();

    if (!exportSuccess) {
      print('❌ Failed to export to individual files.');
      exit(1);
    }

    print('✅ Export completed successfully!');
    print('');

    // Display summary
    final companyFile = service.currentCompanyFile;
    if (companyFile != null) {
      print('📊 Migration Summary:');
      print('   Company: ${companyFile.profile.name}');
      print('   Industry: ${companyFile.profile.industry}');
      print('   Accounts: ${companyFile.accountCount}');
      print('   Transactions: ${companyFile.transactionCount}');
      print('   Suppliers: ${companyFile.supplierCount}');
      print('   Accounting Rules: ${companyFile.ruleCount}');
      print('   File Version: ${companyFile.metadata.version}');
      print('   Created: ${companyFile.metadata.createdAt}');
      print('   Modified: ${companyFile.metadata.modifiedAt}');
      print('');

      print('🎉 Migration completed successfully!');
      print('');
      print('📁 Files created:');
      print('   - data/company_file.json (unified company file)');
      print('   - data/backups/ (automatic backups)');
      print('');
      print('📁 Individual files maintained for backward compatibility:');
      print('   - inputs/accounts.json');
      print('   - data/general_journal.json');
      print('   - inputs/company_profile.txt');
      print('   - inputs/accounting_rules.txt');
      print('   - inputs/supplier_list.json');
      print('');
      print('💡 Next steps:');
      print(
          '   1. Update your code to use services.companyFile instead of individual services');
      print('   2. Test that all functionality still works');
      print(
          '   3. Once confident, you can remove the individual file dependencies');
      print('   4. The company file will be your single source of truth');
    }
  } catch (e, stackTrace) {
    print('❌ Migration failed with error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

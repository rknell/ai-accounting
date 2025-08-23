# 🏢 Company File System Documentation

## Overview

The Company File System is a comprehensive refactoring that consolidates all company-specific data into a single, unified entity. This system provides better data integrity, atomic operations, and centralized management while maintaining backward compatibility.

## 🎯 What Was Consolidated

The following individual files have been consolidated into a single CompanyFile:

- **`data/general_journal.json`** → General journal entries
- **`inputs/accounts.json`** → Chart of accounts
- **`inputs/company_profile.txt`** → Company information and details
- **`inputs/accounting_rules.txt`** → Business logic for transaction categorization
- **`inputs/supplier_list.json`** → Supplier information and categorization

**Note:** CSV files in the `inputs/` directory are NOT included in the company file as they are imported separately.

## 🏗️ Architecture

### Core Components

#### 1. CompanyFile Model (`lib/models/company_file.dart`)

The main data container that holds all company information:

```dart
class CompanyFile {
  final String id;                    // Unique identifier
  final CompanyProfile profile;       // Company information
  final List<Account> accounts;       // Chart of accounts
  final List<GeneralJournal> generalJournal; // Transaction history
  final List<AccountingRule> accountingRules; // Categorization rules
  final List<SupplierModel> suppliers; // Supplier list
  final CompanyFileMetadata metadata; // File metadata
}
```

#### 2. CompanyFileService (`lib/services/company_file_service.dart`)

Centralized service for all company file operations:

- **Loading/Saving**: Unified file operations
- **Migration**: Convert from individual files
- **Validation**: Data integrity checks
- **Backup**: Automatic backup creation
- **Export**: Backward compatibility support

#### 3. Services Integration (`lib/services/services.dart`)

The CompanyFileService is integrated into the main Services class:

```dart
// Access the company file service
final companyFile = services.companyFile;

// Load company file
companyFile.loadCompanyFile('data/company_file.json');

// Access company data
final accounts = companyFile.getAllAccounts();
final suppliers = companyFile.getAllSuppliers();
```

## 🚀 Key Features

### 1. **Data Integrity**
- Comprehensive validation before any save operations
- Automatic backup creation before modifications
- Checksum verification for data integrity

### 2. **Atomic Operations**
- All company data is loaded/saved as a single unit
- Prevents partial updates that could corrupt data
- Transaction-like behavior for data consistency

### 3. **Backward Compatibility**
- Existing code continues to work unchanged
- Individual files are maintained for compatibility
- Gradual migration path available

### 4. **Security**
- No direct file manipulation by LLMs/AIs
- All operations go through the CompanyFileService
- Comprehensive validation and sanitization

### 5. **Performance**
- Single file load instead of multiple file operations
- Efficient data access methods
- Lazy loading and caching support

## 📋 Usage Examples

### Basic Operations

```dart
import 'package:ai_accounting/services/services.dart';

void main() {
  // Access the company file service
  final companyFile = services.companyFile;
  
  // Load a company file
  companyFile.loadCompanyFile('data/company_file.json');
  
  // Access company data
  final profile = companyFile.getCompanyProfile();
  final accounts = companyFile.getAllAccounts();
  final suppliers = companyFile.getAllSuppliers();
  
  // Filter accounts by type
  final revenueAccounts = companyFile.getAccountsByType(AccountType.revenue);
  
  // Find specific account
  final account = companyFile.getAccount('100');
}
```

### Migration from Individual Files

```dart
// Migrate existing individual files to company file
final migrationSuccess = companyFile.migrateFromIndividualFiles();

if (migrationSuccess) {
  // Save the unified company file
  companyFile.saveCompanyFile('data/company_file.json');
  
  // Export back to individual files for backward compatibility
  companyFile.exportToIndividualFiles();
}
```

### Data Validation

```dart
// Validate company file data
final validationErrors = companyFile.validate();

if (validationErrors.isNotEmpty) {
  print('Validation errors found:');
  for (final error in validationErrors) {
    print('  - $error');
  }
} else {
  print('All data is valid!');
}
```

## 🔄 Migration Process

### Step 1: Run Migration Script

```bash
dart bin/migrate_to_company_file.dart
```

This script will:
1. Read all individual files
2. Consolidate them into a CompanyFile
3. Validate the consolidated data
4. Save the unified company file
5. Export back to individual files for compatibility

### Step 2: Update Your Code

Replace direct file access with CompanyFileService calls:

```dart
// OLD: Direct file access
final accounts = jsonDecode(File('inputs/accounts.json').readAsStringSync());

// NEW: Through CompanyFileService
final accounts = services.companyFile.getAllAccounts();
```

### Step 3: Test and Validate

Ensure all functionality works correctly with the new system.

### Step 4: Remove Individual File Dependencies

Once confident, you can remove the individual file dependencies from your code.

## 🛡️ Security Considerations

### File Access Control
- **LLMs/AIs**: Cannot directly manipulate company files
- **Services**: All operations go through CompanyFileService
- **Validation**: Comprehensive validation before any save operations

### Data Integrity
- **Backups**: Automatic backup creation before modifications
- **Checksums**: File integrity verification
- **Validation**: Data structure and business rule validation

### Access Patterns
- **Read-only**: Most operations are read-only
- **Write operations**: Require validation and backup
- **Atomic updates**: All-or-nothing operations

## 🧪 Testing

### Unit Tests
- **CompanyFile Model**: `test/models/company_file_test.dart`
- **CompanyFileService**: `test/services/company_file_service_test.dart`

### Test Mode
The CompanyFileService supports a test mode that prevents actual file operations:

```dart
// Create service in test mode
final service = CompanyFileService(testMode: true);

// All file operations will be skipped
service.loadCompanyFile('test.json'); // Returns true, no actual loading
```

## 📊 Performance Characteristics

### File Operations
- **Single file load**: ~O(1) instead of O(n) for n individual files
- **Memory usage**: Slightly higher due to consolidated data
- **Access patterns**: O(1) for direct access, O(n) for filtering

### Data Access
- **Account lookup**: O(1) by code, O(n) by type
- **Supplier search**: O(n) linear search
- **Journal queries**: O(n) for date ranges

## 🔧 Configuration

### File Paths
Default file paths can be customized:

```dart
companyFile.migrateFromIndividualFiles(
  accountsPath: 'custom/accounts.json',
  generalJournalPath: 'custom/journal.json',
  companyProfilePath: 'custom/profile.txt',
  accountingRulesPath: 'custom/rules.txt',
  supplierListPath: 'custom/suppliers.json',
);
```

### Backup Settings
Backups are automatically created in a `backups/` subdirectory with timestamps.

## 🚨 Error Handling

### Common Errors
1. **File not found**: Individual files missing during migration
2. **Validation errors**: Data integrity issues
3. **Permission errors**: File access denied
4. **Parse errors**: Malformed data in individual files

### Error Recovery
- Automatic backup creation before operations
- Detailed error messages with context
- Graceful fallback to individual files if needed

## 📈 Future Enhancements

### Planned Features
1. **Versioning**: Support for multiple company file versions
2. **Incremental updates**: Delta-based file updates
3. **Compression**: File size optimization
4. **Encryption**: Data security enhancements
5. **Cloud sync**: Multi-device synchronization

### Extension Points
The system is designed to be extensible:
- New data types can be added to CompanyFile
- Custom validation rules can be implemented
- Additional export formats can be supported

## 🤝 Contributing

### Code Standards
- Follow existing code style and patterns
- Include comprehensive tests for new features
- Update documentation for any changes
- Maintain backward compatibility

### Testing Requirements
- All new features must have unit tests
- Integration tests for file operations
- Performance tests for large datasets
- Security tests for validation logic

## 📚 Related Documentation

- [AGENT_UI_USAGE.md](AGENT_UI_USAGE.md) - Agent UI usage patterns
- [TEST_SUITE_SUMMARY.md](../test/TEST_SUITE_SUMMARY.md) - Test suite overview
- [README.md](../README.md) - Project overview

## 🆘 Support

### Troubleshooting
1. **Migration failures**: Check individual file formats and permissions
2. **Validation errors**: Review data structure and business rules
3. **Performance issues**: Consider data size and access patterns

### Getting Help
- Review test files for usage examples
- Check error messages for specific issues
- Run validation to identify data problems
- Use test mode for development and debugging

---

**🏆 Company File System**: Unifying company data management for better integrity, performance, and maintainability.




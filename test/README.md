# 🏆 MCP Server Test Suite

## Overview

This comprehensive test suite validates all functionality of the Accountant MCP Server, ensuring reliability, security, and performance of the accounting system.

## Test Structure

```
test/
├── README.md                           # This file
├── run_mcp_tests.dart                 # Main test runner
├── chart_of_accounts_test.dart        # Existing chart of accounts tests
├── mcp_server/                        # MCP server specific tests
│   ├── accountant_mcp_server_test.dart    # Main MCP server tests
│   ├── supplier_management_test.dart      # Supplier management tests
│   ├── supplier_functionality_demo.dart   # Working supplier demo
│   └── supplier_addition_demo.dart        # Working addition demo
└── test_report_YYYY-MM-DD.txt        # Generated test reports
```

## Running Tests

### Quick Test Run
```bash
dart run test/run_mcp_tests.dart
```

### Individual Test Suites
```bash
# MCP Server functionality
dart test test/mcp_server/accountant_mcp_server_test.dart

# Supplier management
dart test test/mcp_server/supplier_management_test.dart

# Chart of accounts
dart test test/chart_of_accounts_test.dart
```

### Demo Scripts (Non-test)
```bash
# Supplier functionality demonstration
dart run test/mcp_server/supplier_functionality_demo.dart

# Supplier addition demonstration  
dart run test/mcp_server/supplier_addition_demo.dart
```

## Test Coverage

### 🏦 Chart of Accounts Management
- ✅ Bank account protection (001-099 range)
- ✅ Account creation and validation
- ✅ Account code auto-assignment
- ✅ Account type validation
- ✅ GST type validation

### 🏪 Supplier Management
- ✅ Fuzzy matching algorithms
- ✅ Supplier addition and updates
- ✅ Data structure validation
- ✅ Alphabetical sorting
- ✅ Category standardization
- ✅ Edge case handling

### 🔍 Transaction Operations
- ✅ Transaction search by string
- ✅ Transaction search by account
- ✅ Transaction search by date range
- ✅ Transaction search by amount range
- ✅ Transaction ID generation
- ✅ Bank account update protection

### 📋 Accounting Rules
- ✅ Rules file creation and format
- ✅ Rule validation
- ✅ Missing file handling
- ✅ Rule priority system

### 🔧 Integration & Performance
- ✅ Service initialization
- ✅ File system operations
- ✅ JSON parsing and validation
- ✅ Error handling
- ✅ Performance benchmarks

### 🛡️ Security Features
- ✅ Bank account protection
- ✅ Input validation
- ✅ Account code format validation
- ✅ GST handling validation

## Test Types

### 🛡️ REGRESSION Tests
Prevent previously fixed bugs from returning:
- Bank account protection
- Duplicate supplier prevention
- Transaction balance validation

### ✅ FEATURE Tests  
Verify core functionality works correctly:
- Account creation
- Supplier management
- Transaction searching
- Rules management

### 🎯 EDGE_CASE Tests
Handle unusual or boundary conditions:
- Empty data sets
- Invalid input formats
- Missing files
- Malformed JSON

### ⚡ PERFORMANCE Tests
Ensure system performs within acceptable limits:
- Server startup time
- Large data set handling
- Search operation speed

### 🔧 INTEGRATION Tests
Verify components work together:
- Service interactions
- File system operations
- Data persistence
- Cross-component validation

## Adding New Tests

### 1. Create Test File
```dart
import 'package:test/test.dart';

void main() {
  group('Your Test Group', () {
    test('🎯 FEATURE: Your test description', () {
      // Test implementation
      expect(actual, expected);
    });
  });
}
```

### 2. Add to Test Runner
Update `test/run_mcp_tests.dart` to include your new test file.

### 3. Test Naming Convention
- 🛡️ REGRESSION: Tests that prevent known bugs
- ✅ FEATURE: Tests that verify functionality
- 🎯 EDGE_CASE: Tests for boundary conditions
- ⚡ PERFORMANCE: Tests for speed/efficiency
- 🔧 INTEGRATION: Tests for component interaction

## Test Data

### Safe Test Data
Tests use temporary or non-destructive data:
- Unique identifiers with timestamps
- Separate test files when needed
- Cleanup procedures where appropriate

### Production Data
Some tests run against actual data files:
- `inputs/accounts.json`
- `inputs/supplier_list.json` 
- `data/general_journal.json`

These tests are read-only or use safe operations.

## Continuous Integration

The test suite is designed to:
- Run in CI/CD environments
- Generate detailed reports
- Provide clear pass/fail status
- Include performance metrics
- Validate system integrity

## Troubleshooting

### Common Issues

1. **Missing Files**: Test runner will create required directories and empty files
2. **Permission Issues**: Ensure write access to test directories
3. **Dependencies**: Run `dart pub get` if packages are missing
4. **Port Conflicts**: Tests don't use network ports, purely local

### Debug Mode
Add `--verbose` flag for detailed output:
```bash
dart test --verbose test/mcp_server/accountant_mcp_server_test.dart
```

## Contributing

When adding new MCP server functionality:
1. Add corresponding tests
2. Update test coverage documentation
3. Ensure tests follow naming conventions
4. Include both positive and negative test cases
5. Add performance considerations for large operations

## Reports

Test reports are automatically generated in `test/test_report_YYYY-MM-DD.txt` and include:
- Summary statistics
- Individual test results
- Coverage information
- Performance metrics
- Recommendations for improvements

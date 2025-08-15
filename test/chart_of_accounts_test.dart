import 'package:ai_accounting/models/account.dart';
import 'package:ai_accounting/services/chart_of_accounts_service.dart';
import 'package:test/test.dart';

void main() {
  test('ChartOfAccountsService loads accounts from JSON file', () async {
    final service = ChartOfAccountsService();

    // Load accounts
    final success = service.loadAccounts();
    expect(success, isTrue);

    // Verify accounts were loaded
    final accounts = service.getAllAccounts();
    expect(accounts, isNotEmpty);

    // Check for specific account
    final bankAccount = service.getAccount('001');
    expect(bankAccount, isNotNull);
    expect(bankAccount?.name, equals('Rebellion Rum Co'));
    expect(bankAccount?.type, equals(AccountType.bank));
    expect(bankAccount?.gst, isFalse);
    expect(bankAccount?.gstType, equals(GstType.basExcluded));

    // Test filtering by type
    final bankAccounts = service.getAccountsByType(AccountType.bank);
    expect(bankAccounts, isNotEmpty);
    expect(bankAccounts.every((account) => account.type == AccountType.bank),
        isTrue);

    // Verify another account type
    final expenseAccounts = service.getAccountsByType(AccountType.expense);
    expect(expenseAccounts, isNotEmpty);
    expect(
        expenseAccounts.every((account) => account.type == AccountType.expense),
        isTrue);
  });
}

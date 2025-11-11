import 'package:json_annotation/json_annotation.dart';

part 'split_transaction.g.dart';

/// Represents a single line item in a split transaction
///
/// Each split transaction line contains an account code and the amount
/// to be debited or credited to that account.
@JsonSerializable()
class SplitTransaction {
  /// The account code to be debited or credited
  final String accountCode;

  /// The amount to be debited or credited to the account
  final double amount;

  /// Creates a new SplitTransaction line item
  ///
  /// @param accountCode The account code to be debited or credited
  /// @param amount The amount to be debited or credited to the account, rounded to 2 decimal places
  SplitTransaction({
    required this.accountCode,
    required double amount,
  })  : amount = double.parse(amount.toStringAsFixed(2)),
        assert(double.parse(amount.toStringAsFixed(2)) > 0,
            'Amount must be positive');

  /// Creates a SplitTransaction from JSON
  factory SplitTransaction.fromJson(Map<String, dynamic> json) =>
      _$SplitTransactionFromJson(json);

  /// Converts this SplitTransaction to JSON
  Map<String, dynamic> toJson() => _$SplitTransactionToJson(this);
}

import 'package:json_annotation/json_annotation.dart';

part 'ai_query_result.g.dart';

/// Represents the result of AI categorization for an account transaction
///
/// Contains the assigned account code, transaction description, and reasoning
/// for the categorization decision
@JsonSerializable()
class AIQueryResult {
  /// The chart of accounts code assigned to the transaction
  final String accountCode;

  /// The description of the transaction being categorized
  final String description;

  /// The reasoning provided by the AI for this categorization
  final String reasoning;

  /// Creates a new AIAccountResult instance
  AIQueryResult({
    required this.accountCode,
    required this.description,
    required this.reasoning,
  });

  /// Creates an AIQueryResult from JSON
  factory AIQueryResult.fromJson(Map<String, dynamic> json) =>
      _$AIQueryResultFromJson(json);

  /// Converts this AIQueryResult to JSON
  Map<String, dynamic> toJson() => _$AIQueryResultToJson(this);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_query_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AIQueryResult _$AIQueryResultFromJson(Map<String, dynamic> json) =>
    AIQueryResult(
      accountCode: json['accountCode'] as String,
      description: json['description'] as String,
      reasoning: json['reasoning'] as String,
    );

Map<String, dynamic> _$AIQueryResultToJson(AIQueryResult instance) =>
    <String, dynamic>{
      'accountCode': instance.accountCode,
      'description': instance.description,
      'reasoning': instance.reasoning,
    };

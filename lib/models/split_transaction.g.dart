// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'split_transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SplitTransaction _$SplitTransactionFromJson(Map<String, dynamic> json) =>
    SplitTransaction(
      accountCode: json['accountCode'] as String,
      amount: (json['amount'] as num).toDouble(),
    );

Map<String, dynamic> _$SplitTransactionToJson(SplitTransaction instance) =>
    <String, dynamic>{
      'accountCode': instance.accountCode,
      'amount': instance.amount,
    };

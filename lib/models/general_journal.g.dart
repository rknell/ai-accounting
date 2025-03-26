// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'general_journal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeneralJournal _$GeneralJournalFromJson(Map<String, dynamic> json) =>
    GeneralJournal(
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String,
      debits: (json['debits'] as List<dynamic>)
          .map((e) => SplitTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      credits: (json['credits'] as List<dynamic>)
          .map((e) => SplitTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      bankBalance: (json['bankBalance'] as num).toDouble(),
      notes: json['notes'] as String? ?? '',
    );

Map<String, dynamic> _$GeneralJournalToJson(GeneralJournal instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'description': instance.description,
      'debits': instance.debits,
      'credits': instance.credits,
      'bankBalance': instance.bankBalance,
      'notes': instance.notes,
    };

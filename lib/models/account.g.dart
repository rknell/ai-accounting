// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Account _$AccountFromJson(Map<String, dynamic> json) => Account(
      id: (json['_id'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      code: json['code'] as String,
      name: json['name'] as String,
      type: Account._accountTypeFromJson(json['type'] as String),
      gst: json['gst'] as bool,
      gstType: Account._gstTypeFromJson(json['gstType'] as String),
    );

Map<String, dynamic> _$AccountToJson(Account instance) => <String, dynamic>{
      '_id': instance.id,
      'code': instance.code,
      'name': instance.name,
      'type': Account._accountTypeToJson(instance.type),
      'gst': instance.gst,
      'gstType': Account._gstTypeToJson(instance.gstType),
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deepseek_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeepseekMessage _$DeepseekMessageFromJson(Map<String, dynamic> json) =>
    DeepseekMessage(
      content: json['content'] as String,
      reasoningContent: json['reasoning_content'] as String?,
      toolCalls: (json['tool_calls'] as List<dynamic>?)
          ?.map((e) => DeepseekToolCall.fromJson(e as Map<String, dynamic>))
          .toList(),
      role: json['role'] as String,
    );

Map<String, dynamic> _$DeepseekMessageToJson(DeepseekMessage instance) =>
    <String, dynamic>{
      'content': instance.content,
      'reasoning_content': instance.reasoningContent,
      'tool_calls': instance.toolCalls,
      'role': instance.role,
    };

DeepseekChatRequest _$DeepseekChatRequestFromJson(Map<String, dynamic> json) =>
    DeepseekChatRequest(
      messages: (json['messages'] as List<dynamic>)
          .map((e) => DeepseekMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      model: json['model'] as String,
      temperature: (json['temperature'] as num?)?.toDouble(),
      maxTokens: (json['max_tokens'] as num?)?.toInt(),
      topP: (json['top_p'] as num?)?.toDouble(),
      frequencyPenalty: (json['frequency_penalty'] as num?)?.toDouble(),
      presencePenalty: (json['presence_penalty'] as num?)?.toDouble(),
      stream: json['stream'] as bool?,
      responseFormat: json['response_format'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$DeepseekChatRequestToJson(
        DeepseekChatRequest instance) =>
    <String, dynamic>{
      'messages': instance.messages,
      'model': instance.model,
      'temperature': instance.temperature,
      'max_tokens': instance.maxTokens,
      'top_p': instance.topP,
      'frequency_penalty': instance.frequencyPenalty,
      'presence_penalty': instance.presencePenalty,
      'stream': instance.stream,
      'response_format': instance.responseFormat,
    };

DeepseekChoice _$DeepseekChoiceFromJson(Map<String, dynamic> json) =>
    DeepseekChoice(
      finishReason: json['finish_reason'] as String?,
      index: (json['index'] as num).toInt(),
      message:
          DeepseekMessage.fromJson(json['message'] as Map<String, dynamic>),
      logprobs: json['logprobs'] == null
          ? null
          : DeepseekLogprobs.fromJson(json['logprobs'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DeepseekChoiceToJson(DeepseekChoice instance) =>
    <String, dynamic>{
      'finish_reason': instance.finishReason,
      'index': instance.index,
      'message': instance.message,
      'logprobs': instance.logprobs,
    };

DeepseekUsage _$DeepseekUsageFromJson(Map<String, dynamic> json) =>
    DeepseekUsage(
      completionTokens: (json['completion_tokens'] as num).toInt(),
      promptTokens: (json['prompt_tokens'] as num).toInt(),
      promptCacheHitTokens: (json['prompt_cache_hit_tokens'] as num?)?.toInt(),
      promptCacheMissTokens:
          (json['prompt_cache_miss_tokens'] as num?)?.toInt(),
      totalTokens: (json['total_tokens'] as num).toInt(),
      completionTokensDetails: json['completion_tokens_details'] == null
          ? null
          : DeepseekCompletionTokensDetails.fromJson(
              json['completion_tokens_details'] as Map<String, dynamic>),
      promptTokensDetails: json['prompt_tokens_details'] == null
          ? null
          : DeepseekPromptTokensDetails.fromJson(
              json['prompt_tokens_details'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DeepseekUsageToJson(DeepseekUsage instance) =>
    <String, dynamic>{
      'completion_tokens': instance.completionTokens,
      'prompt_tokens': instance.promptTokens,
      'prompt_cache_hit_tokens': instance.promptCacheHitTokens,
      'prompt_cache_miss_tokens': instance.promptCacheMissTokens,
      'total_tokens': instance.totalTokens,
      'completion_tokens_details': instance.completionTokensDetails,
      'prompt_tokens_details': instance.promptTokensDetails,
    };

DeepseekPromptTokensDetails _$DeepseekPromptTokensDetailsFromJson(
        Map<String, dynamic> json) =>
    DeepseekPromptTokensDetails(
      cachedTokens: (json['cached_tokens'] as num?)?.toInt(),
    );

Map<String, dynamic> _$DeepseekPromptTokensDetailsToJson(
        DeepseekPromptTokensDetails instance) =>
    <String, dynamic>{
      'cached_tokens': instance.cachedTokens,
    };

DeepseekChatResponse _$DeepseekChatResponseFromJson(
        Map<String, dynamic> json) =>
    DeepseekChatResponse(
      id: json['id'] as String,
      choices: (json['choices'] as List<dynamic>)
          .map((e) => DeepseekChoice.fromJson(e as Map<String, dynamic>))
          .toList(),
      created: (json['created'] as num).toInt(),
      model: json['model'] as String,
      systemFingerprint: json['system_fingerprint'] as String?,
      object: json['object'] as String,
      usage: DeepseekUsage.fromJson(json['usage'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DeepseekChatResponseToJson(
        DeepseekChatResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'choices': instance.choices,
      'created': instance.created,
      'model': instance.model,
      'system_fingerprint': instance.systemFingerprint,
      'object': instance.object,
      'usage': instance.usage,
    };

DeepseekToolCall _$DeepseekToolCallFromJson(Map<String, dynamic> json) =>
    DeepseekToolCall(
      id: json['id'] as String,
      type: json['type'] as String,
      function:
          DeepseekFunction.fromJson(json['function'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DeepseekToolCallToJson(DeepseekToolCall instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'function': instance.function,
    };

DeepseekFunction _$DeepseekFunctionFromJson(Map<String, dynamic> json) =>
    DeepseekFunction(
      name: json['name'] as String,
      arguments: json['arguments'] as String,
    );

Map<String, dynamic> _$DeepseekFunctionToJson(DeepseekFunction instance) =>
    <String, dynamic>{
      'name': instance.name,
      'arguments': instance.arguments,
    };

DeepseekLogprobContent _$DeepseekLogprobContentFromJson(
        Map<String, dynamic> json) =>
    DeepseekLogprobContent(
      token: json['token'] as String,
      logprob: (json['logprob'] as num).toDouble(),
      bytes: (json['bytes'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      topLogprobs: (json['top_logprobs'] as List<dynamic>)
          .map((e) => DeepseekTopLogprob.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DeepseekLogprobContentToJson(
        DeepseekLogprobContent instance) =>
    <String, dynamic>{
      'token': instance.token,
      'logprob': instance.logprob,
      'bytes': instance.bytes,
      'top_logprobs': instance.topLogprobs,
    };

DeepseekTopLogprob _$DeepseekTopLogprobFromJson(Map<String, dynamic> json) =>
    DeepseekTopLogprob(
      token: json['token'] as String,
      logprob: (json['logprob'] as num).toDouble(),
      bytes: (json['bytes'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$DeepseekTopLogprobToJson(DeepseekTopLogprob instance) =>
    <String, dynamic>{
      'token': instance.token,
      'logprob': instance.logprob,
      'bytes': instance.bytes,
    };

DeepseekLogprobs _$DeepseekLogprobsFromJson(Map<String, dynamic> json) =>
    DeepseekLogprobs(
      content: (json['content'] as List<dynamic>)
          .map(
              (e) => DeepseekLogprobContent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DeepseekLogprobsToJson(DeepseekLogprobs instance) =>
    <String, dynamic>{
      'content': instance.content,
    };

DeepseekCompletionTokensDetails _$DeepseekCompletionTokensDetailsFromJson(
        Map<String, dynamic> json) =>
    DeepseekCompletionTokensDetails(
      reasoningTokens: (json['reasoning_tokens'] as num?)?.toInt(),
    );

Map<String, dynamic> _$DeepseekCompletionTokensDetailsToJson(
        DeepseekCompletionTokensDetails instance) =>
    <String, dynamic>{
      'reasoning_tokens': instance.reasoningTokens,
    };

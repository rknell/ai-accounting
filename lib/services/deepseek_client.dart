import 'dart:convert';

import 'package:ai_accounting/models/deepseek_models.dart';
import 'package:ai_accounting/services/environment_service.dart';
import 'package:http/http.dart' as http;

/// A service class that handles communication with the DeepSeek API.
/// This service provides methods to interact with DeepSeek's chat completion API.
class DeepseekClient {
  /// Base URL for the DeepSeek API
  static const String _baseUrl = 'https://api.deepseek.com';

  /// Endpoint for chat completions
  static const String _chatEndpoint = '/chat/completions';

  /// HTTP client for making API requests
  final client = http.Client();

  /// The model to use for generating completions
  /// Defaults to the model specified in environment variables
  String model = environment.deepseekModel;

  /// Controls randomness in the response (0.0 to 2.0)
  /// Higher values make output more random, lower values make it more deterministic
  double temperature = 1.0;

  /// Maximum number of tokens to generate in the response
  int maxTokens = 4096;

  /// Controls diversity via nucleus sampling (0.0 to 1.0)
  /// 0.1 means only tokens with the top 10% probability are considered
  double? topP;

  /// Reduces repetition of token sequences (-2.0 to 2.0)
  /// Positive values decrease the likelihood of repeating the same line
  double? frequencyPenalty;

  /// Encourages talking about new topics (-2.0 to 2.0)
  /// Positive values increase the model's likelihood to talk about new topics
  double? presencePenalty;

  /// Whether to stream the response
  bool? stream;

  /// Specifies the format of the response
  Map<String, dynamic>? responseFormat;

  /// List of messages in the conversation
  /// Each message contains a role (system, user, assistant) and content
  final messages = <DeepseekMessage>[];

  /// Creates a new instance of [DeepseekClient].
  DeepseekClient();

  /// Clears the conversation history by removing all messages from the context.
  ///
  /// This method resets the conversation state, allowing you to start a new
  /// conversation without creating a new client instance. Call this method
  /// when you want to begin a fresh conversation with the DeepSeek API.
  void clearContext() {
    messages.clear();
  }

  /// Creates a chat completion using the DeepSeek API.
  ///
  /// This method sends the provided [message] to the DeepSeek API along with any
  /// conversation history stored in the [messages] list. It returns a [DeepseekChatResponse]
  /// containing the model's response.
  ///
  /// The request uses the client's current configuration settings including:
  /// - [model]: The AI model to use (from environment variables by default)
  /// - [temperature]: Controls randomness (0.0-2.0)
  /// - [maxTokens]: Maximum tokens to generate
  /// - Other parameters like [topP], [frequencyPenalty], etc.
  ///
  /// Throws a [DeepseekException] if:
  /// - The API key is not found in environment variables
  /// - The API request fails
  /// - Any other error occurs during the request
  ///
  /// Example:
  /// ```dart
  /// final response = await client.createChatCompletion(
  ///   message: "What is the capital of France?"
  /// );
  /// print(response.choices.first.message.content);
  /// ```
  Future<String> sendMessage({required String message}) async {
    final apiKey = environment.deepseekApiKey;

    messages.add(DeepseekMessage(role: 'user', content: message));

    final request = DeepseekChatRequest(
      messages: messages,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      topP: topP,
      frequencyPenalty: frequencyPenalty,
      presencePenalty: presencePenalty,
      stream: stream,
      responseFormat: responseFormat,
    );

    try {
      final response = await client.post(
        Uri.parse('$_baseUrl$_chatEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        print(response.body);

        var output = DeepseekChatResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );

        messages.add(output.firstMessage);

        return output.firstMessage.content;
      } else {
        throw DeepseekException(
          'API request failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      throw DeepseekException(
          'Failed to create chat completion: $e\nStack trace: $stackTrace');
    }
  }

  /// Closes the HTTP client.
  void dispose() {
    client.close();
  }
}

/// Exception thrown when the DeepSeek API request fails.
///
/// This exception is used to handle errors that occur during API requests to the DeepSeek service.
/// It captures error messages from various failure scenarios such as missing API keys,
/// network errors, or invalid responses from the DeepSeek API.
class DeepseekException implements Exception {
  /// The error message describing what went wrong with the API request.
  ///
  /// This message provides details about the specific error that occurred,
  /// which can be useful for debugging and error handling.
  final String message;

  /// Creates a new [DeepseekException] with the specified error [message].
  ///
  /// @param message A description of the error that occurred.
  DeepseekException(this.message);

  @override

  /// Returns a string representation of this exception.
  ///
  /// The returned string includes the class name and the error message.
  String toString() => 'DeepseekException: $message';
}

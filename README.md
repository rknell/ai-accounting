# AI Accounting

An AI-powered accounting application that leverages the DeepSeek API for intelligent financial analysis and assistance.

## Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Create a `.env` file in the root directory with your DeepSeek API key:
   ```
   DEEPSEEK_API_KEY=your_api_key_here
   ```
4. Generate the JSON serialization code:
   ```bash
   flutter pub run build_runner build
   ```

## Usage

The DeepSeek client is registered as a singleton with GetIt dependency injection. Here's how to use it:

```dart
import 'package:get_it/get_it.dart';
import 'services/deepseek_client.dart';
import 'models/deepseek_models.dart';

// Get the DeepSeek client instance
final deepseekClient = GetIt.instance<DeepseekClient>();

// Create a chat completion
final response = await deepseekClient.createChatCompletion(
  messages: [
    DeepseekMessage(
      role: 'system',
      content: 'You are a helpful accounting assistant.',
    ),
    DeepseekMessage(
      role: 'user',
      content: 'Help me analyze this financial statement.',
    ),
  ],
  model: 'deepseek-chat',
  temperature: 0.7,
  maxTokens: 2048,
);

// Access the response
print(response.choices.first.message.content);
```

## Features

- Integration with DeepSeek's chat completion API
- JSON serialization for request/response models
- Proper error handling and exception management
- Environment variable configuration
- Dependency injection with GetIt

## Error Handling

The client throws `DeepseekException` when API requests fail. Always wrap API calls in try-catch blocks:

```dart
try {
  final response = await deepseekClient.createChatCompletion(...);
  // Handle successful response
} catch (e) {
  if (e is DeepseekException) {
    // Handle API-specific errors
  } else {
    // Handle other errors
  }
}
```

## Configuration

The client can be configured with the following parameters:

- `temperature`: Controls randomness (0.0 to 2.0)
- `maxTokens`: Limits response length
- `topP`: Controls diversity via nucleus sampling (0.0 to 1.0)
- `frequencyPenalty`: Reduces repetition (-2.0 to 2.0)
- `presencePenalty`: Encourages new topics (-2.0 to 2.0)
- `stream`: Enable streaming responses
- `responseFormat`: Specify response format 


# TODO:

- Automatic backup of records to google drive
- Make records GST exclusive, split the transactions, and put the tax in the GST account (so it doesn't appear in the profit and loss and the profit and losses aren't overstated by 10%)

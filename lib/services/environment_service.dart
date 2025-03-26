import 'package:dotenv/dotenv.dart';
import 'package:get_it/get_it.dart';

/// Service responsible for managing environment variables in the application.
///
/// This service handles:
/// - Loading environment variables from .env files and platform environment
/// - Providing access to configuration values throughout the application
/// - Validating required environment variables on initialization
/// - Offering type-safe access to specific configuration values
class EnvironmentService {
  /// The environment variables loaded from .env file
  final DotEnv _env;

  /// Creates a new instance of [EnvironmentService].
  ///
  /// Loads environment variables from the platform environment and .env file.
  /// The platform environment variables take precedence over the .env file.
  /// 
  /// Throws an [Exception] if required environment variables are missing:
  /// - DEEPSEEK_API_KEY: Required for API authentication
  /// - DEEPSEEK_MODEL: Required to specify which model to use
  EnvironmentService()
      : _env = DotEnv(includePlatformEnvironment: true)..load() {
    // Validate required environment variables
    if (deepseekApiKey.isEmpty) {
      throw Exception(
          'API key not found. Please set DEEPSEEK_API_KEY in your .env file.');
    }

    if (deepseekModel.isEmpty) {
      throw Exception(
          'Model name not found. Please set DEEPSEEK_MODEL in your .env file.');
    }
  }

  /// Gets an environment variable by key.
  ///
  /// Returns the value of the environment variable with the given [key].
  /// If the environment variable is not found, returns [defaultValue].
  /// 
  /// Example:
  /// ```dart
  /// final port = int.parse(environment.get('PORT', defaultValue: '8080'));
  /// ```
  String get(String key, {String defaultValue = ''}) {
    return _env[key] ?? defaultValue;
  }

  /// Gets the DeepSeek API key.
  ///
  /// Returns the DeepSeek API key from the environment variables.
  /// If not found, returns an empty string.
  /// 
  /// This key is required for authenticating requests to the DeepSeek API.
  String get deepseekApiKey => get('DEEPSEEK_API_KEY');

  /// Gets the DeepSeek model name.
  ///
  /// Returns the DeepSeek model identifier from the environment variables.
  /// If not found, returns an empty string.
  /// This value is used to specify which AI model to use for processing.
  /// 
  /// Common values might include model versions like 'deepseek-coder-v1.5'.
  String get deepseekModel => get('DEEPSEEK_MODEL');
}

/// Global accessor for the EnvironmentService instance
///
/// This getter provides a singleton instance of the EnvironmentService,
/// registering it with GetIt if it hasn't been registered yet.
/// This allows for consistent access to environment variables throughout the application.
EnvironmentService get environment {
  if (GetIt.instance.isRegistered<EnvironmentService>() == false) {
    GetIt.instance.registerSingleton<EnvironmentService>(EnvironmentService());
  }
  return GetIt.instance.get<EnvironmentService>();
}

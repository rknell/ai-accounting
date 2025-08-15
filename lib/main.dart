import 'package:dotenv/dotenv.dart';

Future<void> main() async {
  // Load environment variables
  DotEnv(includePlatformEnvironment: true).load();

  // Remove any AccountCodeService, DeepseekClient, AIQueryResult, or getAccountCode references

  try {
    // The original code had client.sendMessage(message: "Hey how are you doing?");
    // This line is removed as per the edit hint.

    // Print messages with formatting
    // The original code had a loop to iterate through client.messages.
    // This loop is removed as per the edit hint.
  } catch (e) {
    print('Error: $e');
  } finally {
    // The original code had client.dispose();
    // This line is removed as per the edit hint.
  }
}

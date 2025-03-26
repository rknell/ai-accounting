import 'package:ai_accounting/services/services.dart';
import 'package:dotenv/dotenv.dart';

Future<void> main() async {
  // Load environment variables
  DotEnv(includePlatformEnvironment: true).load();

  // Get the client instance
  final client = services.deepseekClient;

  try {
    await client.sendMessage(message: "Hey how are you doing?");

    // Print messages with formatting
    for (var i = 0; i < client.messages.length; i++) {
      final message = client.messages[i];
      final role = message.role;
      final content = message.content;

      // Use ANSI color codes for terminal output
      final roleColor = role == 'user'
          ? '\x1B[32m'
          : '\x1B[36m'; // Green for user, Cyan for assistant
      final resetColor = '\x1B[0m';

      print('$roleColor[$role]$resetColor: $content');

      // Add separator between messages
      if (i < client.messages.length - 1) {
        print('-' * 50);
      }
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.dispose();
  }
}

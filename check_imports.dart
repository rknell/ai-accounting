import 'package:dart_openai_client/dart_openai_client.dart';

void main() {
  // Test if MCP classes are available
  MCPTool(
    name: 'test',
    inputSchema: const {},
  );

  MCPToolResult(
    content: [MCPContent.text('test')],
  );

  print('MCP classes are available!');
}

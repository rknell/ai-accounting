import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:test/test.dart';

void main() {
  test('dart_openai_client exports tool APIs', () {
    final tool = MCPTool(name: 'smoke', inputSchema: const {});
    final result = MCPToolResult(content: [MCPContent.text('ok')]);
    expect(tool.name, equals('smoke'));
    expect(result.content.first.text, equals('ok'));
  });

  test('dart_openai_client exports ApiClient symbol', () {
    final clientType = ApiClient;
    expect(clientType, equals(ApiClient));
  });
}

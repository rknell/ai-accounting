import 'package:test/test.dart';

import '../../mcp/mcp_server_puppeteer.dart';

void main() {
  group('🛡️ REGRESSION: Puppeteer MCP Server', () {
    late PuppeteerMCPServerSimple server;

    setUp(() async {
      server = PuppeteerMCPServerSimple(headless: true);
      await server.initializeServer();
    });

    tearDown(() async {
      // Ensure browser resources are cleaned up between tests
      try {
        await server.callTool('puppeteer_close_browser', {});
      } catch (_) {
        // Ignore cleanup errors if browser never launched
      }
    });

    test('✅ FEATURE: registers core tools', () async {
      final toolNames =
          server.getAvailableTools().map((tool) => tool.name).toSet();

      expect(
        toolNames,
        containsAll([
          'puppeteer_navigate',
          'puppeteer_get_inner_text',
          'puppeteer_get_inner_html',
          'puppeteer_close_browser',
        ]),
      );
    });

    test('🛡️ REGRESSION: navigate html returns expected content', () async {
      const htmlSnippet =
          '<html><body><h1 id="headline">Puppeteer smoke test</h1></body></html>';

      final result = await server.callTool('puppeteer_navigate_html', {
        'url': 'data:text/html,$htmlSnippet',
        'waitUntil': 'load',
        'timeout': 5000,
      });

      final content = result.content.first.text!;
      expect(content, contains('Puppeteer smoke test'));
    }, timeout: Timeout(Duration(seconds: 60)));
  });
}

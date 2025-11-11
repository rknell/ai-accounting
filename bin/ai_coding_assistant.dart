import "dart:convert";
import "dart:io";

import "package:dart_openai_client/dart_openai_client.dart";

/// Simple and robust terminal input handler
String _getUserInput() {
  stdout.write("\nEnter your coding request: ");
  stdout.flush();

  try {
    final input = stdin.readLineSync();
    return input?.trim() ?? '';
  } catch (e) {
    // If there's an issue with stdin, provide a clear message
    print("\n⚠️  Input error. Please try again.");
    return '';
  }
}

/// AI CODING ASSISTANT: Professional Code Analysis & Development
///
/// Provides:
/// 1. Codebase analysis and architectural insights
/// 2. Filesystem access for project structure analysis
/// 3. Code quality assessment and technical debt analysis
/// 4. Refactoring recommendations
/// 5. Integration with development tools
/// 6. Interactive code review workflow
///
/// Security: Read-only operations by default, validation of file operations
Future<void> main() async {
  print("AI CODING ASSISTANT: Code Analysis & Development");
  print("=" * 50);
  print("Professional code analysis and refactoring assistance");
  print("=" * 50);

  final tipsFile = File("bin/coding_assistant_tips.txt");
  String tips = "";
  if (tipsFile.existsSync()) {
    tips = tipsFile.readAsStringSync();
  }

  // Environment validation: Ensure API key is available
  final apiKey = Platform.environment['DEEPSEEK_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    throw Exception("❌ CRITICAL FAILURE: DEEPSEEK_API_KEY is not set");
  }

  // Client initialization: Setup API client
  final client = ApiClient(
    baseUrl: "https://api.deepseek.com/v1",
    apiKey: apiKey,
  );

  // MCP configuration: Load and initialize MCP servers
  final mcpConfig = File("config/mcp_servers.json");
  if (!mcpConfig.existsSync()) {
    throw Exception(
        "❌ CRITICAL FAILURE: MCP configuration not found at config/mcp_servers.json");
  }

  final toolRegistry = McpToolExecutorRegistry(mcpConfig: mcpConfig);
  await toolRegistry.initialize();
  print("✅ MCP servers initialized successfully");

  // System prompt construction: Build coding context
  final systemPrompt = _buildSystemPrompt(tips);

  // Agent initialization: Create coding assistant agent
  final agent = Agent(
    apiClient: client,
    toolRegistry: toolRegistry,
    systemPrompt: systemPrompt,
  )..temperature = 0.8; // Higher temperature for creative technical insights

  print("✅ Coding Assistant initialized and ready");
  print("=" * 50);

  // Project analysis: Perform initial codebase assessment
  await _performInitialAnalysis(toolRegistry);

  try {
    // Interactive workflow: Main coding assistance loop
    await _runInteractiveWorkflow(agent);
  } finally {
    // Cleanup: Ensure proper shutdown
    print("\nShutting down systems...");
    await toolRegistry.shutdown();
    await client.close();
    print("✅ Clean shutdown completed");
  }
}

/// Project analysis: Perform initial codebase assessment
Future<void> _performInitialAnalysis(
    McpToolExecutorRegistry toolRegistry) async {
  print("🔍 Performing initial project analysis...");

  try {
    // Get project structure
    final structureCall = ToolCall(
      id: 'analyze_structure_${DateTime.now().millisecondsSinceEpoch}',
      type: 'function',
      function: ToolCallFunction(
        name: 'directory_tree',
        arguments: jsonEncode({"path": "."}),
      ),
    );
    await toolRegistry.executeTool(structureCall);

    // Get pubspec.yaml for dependencies
    final pubspecCall = ToolCall(
      id: 'read_pubspec_${DateTime.now().millisecondsSinceEpoch}',
      type: 'function',
      function: ToolCallFunction(
        name: 'read_text_file',
        arguments: jsonEncode({"path": "pubspec.yaml"}),
      ),
    );
    await toolRegistry.executeTool(pubspecCall);

    print("✅ Project structure analyzed");
    print("✅ Dependencies identified");
  } catch (e) {
    print("⚠️  Initial analysis limited: $e");
    print("📝 Proceeding with standard coding assistance...");
  }
}

/// Interactive workflow: Main coding assistance loop
Future<void> _runInteractiveWorkflow(Agent agent) async {
  print("INTERACTIVE CODE ANALYSIS");
  print(
      "Enter your coding request, file path for review, or architectural question.");
  print("Available commands:");
  print("  - 'analyze <file/dir>' - Code analysis");
  print("  - 'review <file>' - Code review");
  print("  - 'arch <topic>' - Architectural guidance");
  print("  - 'refactor <file>' - Refactoring recommendations");
  print("  - 'exit', 'quit', or 'done' - End session");
  print("=" * 50);

  while (true) {
    // User input: Get coding request with improved terminal handling
    final userInput = _getUserInput();

    if (userInput.isEmpty) {
      print("❌ No input provided. Please enter a coding request.");
      continue;
    }

    // Exit conditions: Check for session termination
    if (['exit', 'quit', 'done'].contains(userInput.toLowerCase())) {
      print("Session terminated.");
      break;
    }

    print("\nProcessing request: \"$userInput\"");
    print("-" * 40);

    try {
      // Agent processing: Send to coding assistant
      final result = await agent.sendMessage(userInput);

      // Results display: Show coding insights
      print("ANALYSIS COMPLETE:");
      print(result.content);

      // Session continuation: Prepare for next request
      print("-" * 40);
      print("✅ Analysis completed. Ready for next request.");
    } catch (e) {
      // Error handling: Handle coding assistance failures
      print("❌ ANALYSIS FAILED: $e");
      print("Try a different approach or file path.");
    }
  }
}

/// System prompt builder: Create coding context
String _buildSystemPrompt(String tips) {
  return """
AI CODING ASSISTANT: Code Analysis & Development

You are an AI coding assistant that provides professional code analysis and development guidance.

AVAILABLE TOOLS:
- Filesystem access for project structure analysis
- Code analysis tools for Dart code examination
- Project understanding via pubspec.yaml and dependencies
- Integration with development tools
- File-specific code reviews

CAPABILITIES:
- Codebase analysis and architectural assessment
- Technical insights based on software engineering principles
- Actionable recommendations for code improvement
- Code quality and maintainability evaluation
- Professional technical documentation

PROJECT CONTEXT:
You are assisting with a Dart application project. The project includes:
- Multiple MCP servers for various operations
- Integration with AI models
- Modern Dart architecture with separation of concerns

RESPONSE STRATEGY:
1. Analyze project structure and relevant files using available tools
2. Provide specific, actionable technical recommendations
3. Create practical development roadmap with next steps
4. Deliver clear vision of optimized code architecture
5. Summarize with practical technical insights

ACTION PROTOCOL:
When user provides file path or coding request:
1. Use filesystem tools to read and analyze relevant code
2. Examine project context and architecture
3. Provide specific recommendations with code examples
4. Justify recommendations with technical reasoning

Be direct, professional, and focused on practical solutions. Avoid unnecessary fluff or self-aggrandizement.

Tips:
$tips
""";
}

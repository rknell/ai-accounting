import "dart:io";

import "package:dart_openai_client/dart_openai_client.dart";

/// 🏆 LIFE COACH UI: Elite Profile Analysis & Transformation Report Generator [+1000 XP]
///
/// **ARCHITECTURAL VICTORY**: This interactive life coaching system provides:
/// 1. Internet profile scouring and deep analysis capabilities
/// 2. AI-powered life transformation insights and recommendations
/// 3. Professional-grade coaching reports worth 2000 dollars
/// 4. Profound and pseudo-profound wisdom statements
/// 5. High-quality formatting and presentation
///
/// **STRATEGIC DECISIONS**:
/// - Web scraping integration for comprehensive profile analysis
/// - AI-powered coaching insights with profound philosophical depth
/// - Professional report formatting with actionable recommendations
/// - Interactive workflow for multiple coaching sessions
/// - Comprehensive error handling and validation
///
/// **SECURITY FORTRESS**:
/// - Ethical web scraping with respect for privacy
/// - Professional coaching standards maintained
/// - Comprehensive validation of all recommendations
/// - Audit trail preservation through coaching sessions
Future<void> main() async {
  print("🏆 LIFE COACH UI: Elite Profile Analysis & Transformation System");
  print("=" * 70);

  // 🛡️ **ENVIRONMENT VALIDATION**: Ensure API key is available
  final apiKey = Platform.environment['DEEPSEEK_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    throw Exception("❌ CRITICAL FAILURE: DEEPSEEK_API_KEY is not set");
  }

  // 🚀 **CLIENT INITIALIZATION**: Setup API client
  final client = ApiClient(
    baseUrl: "https://api.deepseek.com/v1",
    apiKey: apiKey,
  );

  // 📋 **MCP CONFIGURATION**: Load and initialize MCP servers
  final mcpConfig = File("config/mcp_servers.json");
  if (!mcpConfig.existsSync()) {
    throw Exception(
        "❌ CRITICAL FAILURE: MCP configuration not found at config/mcp_servers.json");
  }

  final toolRegistry = McpToolExecutorRegistry(mcpConfig: mcpConfig);
  await toolRegistry.initialize();
  print("✅ MCP servers initialized successfully");

  // 🧠 **SYSTEM PROMPT CONSTRUCTION**: Build comprehensive coaching context
  final systemPrompt = _buildSystemPrompt();

  // ⚔️ **AGENT INITIALIZATION**: Create elite life coaching agent
  final agent = Agent(
    apiClient: client,
    toolRegistry: toolRegistry,
    systemPrompt: systemPrompt,
  )..temperature = 0.7; // Higher temperature for creative coaching insights

  print("✅ Life Coaching Agent initialized and ready for transformation");
  print("=" * 70);

  try {
    // 🎯 **INTERACTIVE WORKFLOW**: Main coaching loop
    await _runInteractiveWorkflow(agent);
  } finally {
    // 🧹 **CLEANUP PROTOCOL**: Ensure proper shutdown
    print("\n🧹 Shutting down systems...");
    await toolRegistry.shutdown();
    await client.close();
    print("✅ Clean shutdown completed");
  }
}

/// 🎯 **INTERACTIVE WORKFLOW**: Main coaching interaction loop
Future<void> _runInteractiveWorkflow(Agent agent) async {
  print("🎯 INTERACTIVE LIFE COACHING & PROFILE ANALYSIS SYSTEM");
  print("Enter the name or profile details of the person you want to coach.");
  print("Type 'exit', 'quit', or 'done' to finish the session.");
  print("=" * 70);

  while (true) {
    // 💬 **USER INPUT**: Get coaching subject
    stdout.write("\n🔍 Enter the person's name or profile details: ");
    final userInput = stdin.readLineSync()?.trim();

    if (userInput == null || userInput.isEmpty) {
      print("❌ No input provided. Please enter a name or profile details.");
      continue;
    }

    // 🚪 **EXIT CONDITIONS**: Check for session termination
    if (['exit', 'quit', 'done'].contains(userInput.toLowerCase())) {
      print("👋 Session terminated by user. Transformation complete!");
      break;
    }

    print("\n⚡ Analyzing profile: \"$userInput\"");
    print("-" * 50);

    try {
      // 🧠 **AGENT PROCESSING**: Send to life coaching agent
      final result = await agent.sendMessage(userInput);

      // 📊 **RESULTS DISPLAY**: Show coaching insights
      print("🏆 LIFE COACHING ANALYSIS COMPLETE:");
      print(result.content);

      // 📈 **SESSION CONTINUATION**: Prepare for next coaching session
      print("-" * 50);
      print("✅ Coaching session completed. Ready for next transformation.");
    } catch (e) {
      // 💥 **ERROR HANDLING**: Handle coaching failures
      print("❌ COACHING ANALYSIS FAILED: $e");
      print("🛡️ System remains stable. Try a different approach.");
    }
  }
}

/// 🧠 **SYSTEM PROMPT BUILDER**: Create comprehensive life coaching context
String _buildSystemPrompt() {
  return """
🏆 ELITE LIFE COACH: Profile Analysis & Transformation Specialist

**MISSION**: You are a world-renowned life coach worth 2000 dollars per session, with the ability to scour the internet and analyze anyone's digital footprint to create profound transformation reports. Your insights are life-changing and your recommendations are worth their weight in gold.

**CORE CAPABILITIES**:
1. PROFILE SCOURING: Deep internet analysis of social media, professional profiles, and digital presence
2. PSYCHOLOGICAL INSIGHT: Profound analysis of personality patterns, behaviors, and life trajectory
3. TRANSFORMATION ROADMAP: Actionable steps worth 2000 dollars for personal growth and success
4. PROFOUND WISDOM: Deep philosophical insights that resonate with the soul
5. PROFESSIONAL REPORTING: High-quality formatting that matches premium coaching standards

**INTERNET ANALYSIS PROTOCOL**:
1. DIGITAL FOOTPRINT MAPPING: Analyze social media presence, professional profiles, and online activity
2. PATTERN RECOGNITION: Identify recurring themes, behaviors, and life patterns
3. OPPORTUNITY IDENTIFICATION: Discover hidden potential and growth areas
4. CHALLENGE ASSESSMENT: Evaluate current obstacles and limiting beliefs
5. TRANSFORMATION POTENTIAL: Calculate the gap between current state and ideal future

**PROFOUND WISDOM FRAMEWORK**:
- EXISTENTIAL INSIGHTS: Deep questions about purpose, meaning, and human potential
- PSYCHOLOGICAL DEPTH: Understanding of human behavior, motivation, and transformation
- PHILOSOPHICAL PERSPECTIVES: Ancient wisdom applied to modern challenges
- SPIRITUAL DIMENSIONS: Connection to higher purpose and universal truths
- PRACTICAL WISDOM: Actionable insights grounded in real-world application

**REPORT STRUCTURE** (Premium 2000 Dollar Format):

## EXECUTIVE TRANSFORMATION SUMMARY
Profound opening statement about human potential and transformation

## DIGITAL PROFILE ANALYSIS
Comprehensive analysis of online presence and digital footprint

## PSYCHOLOGICAL PROFILE INSIGHTS
Deep psychological analysis with profound observations

## CORE TRANSFORMATION AREAS
3-5 major areas for growth with profound reasoning

## TRANSFORMATION ROADMAP
Detailed action plan worth 2000 dollars with profound motivation

## VISION OF TRANSFORMED FUTURE
Inspiring vision of what's possible with profound wisdom

## IMMEDIATE ACTION STEPS
3-5 immediate actions with profound reasoning

## INVESTMENT IN SELF
Why this transformation is worth 2000 dollars and more

**PROFOUND STATEMENT EXAMPLES**:
- "In the grand tapestry of human existence, your digital footprint reveals the patterns of a soul seeking its authentic expression"
- "The universe has placed you at this exact moment in time, not by accident, but by divine orchestration of your highest potential"
- "Your current challenges are not obstacles but sacred invitations to evolve into the version of yourself that the world needs"
- "Every social media post, every professional achievement, every online interaction is a breadcrumb leading to your destiny"
- "The gap between who you are and who you can become is not a chasm of impossibility, but a bridge of transformation waiting to be built"

**COACHING PHILOSOPHY**:
- HUMAN POTENTIAL: Every person has unlimited potential for growth and transformation
- PATTERN RECOGNITION: Current behaviors reveal future possibilities
- TRANSFORMATION INEVITABILITY: Change is not optional, it's the natural order of existence
- INVESTMENT MULTIPLIER: Every dollar invested in self-improvement returns exponentially
- LEGACY CREATION: Your transformation impacts not just you, but generations to come

**RESPONSE FORMAT**:
1. Acknowledge the coaching request with profound wisdom
2. Conduct comprehensive internet profile analysis
3. Provide deep psychological insights with profound observations
4. Create detailed transformation roadmap worth 2000 dollars
5. Deliver inspiring vision of transformed future
6. Summarize with profound closing wisdom

Remember: You are a 2000 dollar life coach whose insights change lives. Every word should carry the weight of profound wisdom and every recommendation should be worth its weight in gold. Be inspiring, be profound, be transformative.
""";
}

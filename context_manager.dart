// Context Management System for AI Coding Assistant
// Provides efficient token usage and session persistence

import 'dart:convert';
import 'dart:io';

/// Context manager for handling large language model context windows
/// with session persistence and token optimization
class ContextManager {
  /// Maximum tokens before compression is required
  static const int maxContextTokens = 90000; // Safe buffer
  
  /// Threshold when to start summarizing context
  static const int summaryThreshold = 50000; // When to start summarizing
  
  /// Unique session identifier
  final String sessionId;
  
  /// Working directory for session persistence
  final String workingDirectory;
  
  /// Create a new context manager with session ID and working directory
  ContextManager(this.sessionId, this.workingDirectory);
  
  // Session state management
  Map<String, dynamic> _sessionState = {};
  List<String> _contextSummaries = [];
  
  // Track token usage
  int _estimatedTokens = 0;
  
  /// Add content to context and track token usage
  void addToContext(String content, {int estimatedTokens = 100}) {
    _estimatedTokens += estimatedTokens;
    
    if (_estimatedTokens > summaryThreshold) {
      _summarizeContext();
    }
    
    if (_estimatedTokens > maxContextTokens) {
      _compressContext();
    }
  }
  
  /// Summarize current context to reduce token usage
  void _summarizeContext() {
    // Create summary of recent context
    final summary = 'Summary at ${DateTime.now()}: Estimated tokens: $_estimatedTokens';
    _contextSummaries.add(summary);
    
    // Reset token counter for new context window
    _estimatedTokens = 20000; // Reserve for new content
  }
  
  /// Compress context by keeping only essential summaries
  void _compressContext() {
    // Implement context compression strategy
    // Keep only essential summaries and recent content
    if (_contextSummaries.length > 5) {
      _contextSummaries = _contextSummaries.sublist(_contextSummaries.length - 3);
    }
    
    _estimatedTokens = 30000; // Reset with buffer
  }
  
  /// Save current session state to disk
  Future<void> saveSession() async {
    final sessionFile = File('$workingDirectory/session_$sessionId.json');
    final sessionData = {
      'sessionId': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
      'estimatedTokens': _estimatedTokens,
      'contextSummaries': _contextSummaries,
      'sessionState': _sessionState,
    };
    
    await sessionFile.writeAsString(jsonEncode(sessionData));
  }
  
  /// Load session state from disk
  Future<void> loadSession() async {
    final sessionFile = File('$workingDirectory/session_$sessionId.json');
    if (await sessionFile.exists()) {
      final content = await sessionFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      _estimatedTokens = data['estimatedTokens'] as int? ?? 0;
      _contextSummaries = List<String>.from(data['contextSummaries'] as List<dynamic>? ?? []);
      _sessionState = Map<String, dynamic>.from(data['sessionState'] as Map<String, dynamic>? ?? {});
    }
  }
  
  // Todo list for session continuity
  final List<String> _todoItems = [];
  
  /// Add a todo item for session continuity
  void addTodo(String item) {
    _todoItems.add('${DateTime.now().toIso8601String()}: $item');
  }
  
  /// Get all current todo items
  List<String> getTodos() => List<String>.from(_todoItems);
  
  /// Mark a todo item as completed
  void completeTodo(int index) {
    if (index >= 0 && index < _todoItems.length) {
      _todoItems[index] = '[DONE] ${_todoItems[index]}';
    }
  }
  
  /// Get current estimated token count
  int get estimatedTokens => _estimatedTokens;
  
  /// Get current context summaries
  List<String> get contextSummaries => List<String>.from(_contextSummaries);
}

/// Create a new context manager with auto-generated session ID
ContextManager createContextManager() {
  final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  return ContextManager(sessionId, Directory.current.path);
}
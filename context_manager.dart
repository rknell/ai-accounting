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
  
  // Ephemeral content tracking (files, tool results that can be cleaned up)
  final Map<String, List<String>> _ephemeralContent = {};
  final Set<String> _currentFiles = {};
  
  /// Add content to context and track token usage
  void addToContext(String content, {int estimatedTokens = 100, bool ephemeral = false, String? contentId}) {
    _estimatedTokens += estimatedTokens;
    
    // Track ephemeral content for cleanup
    if (ephemeral && contentId != null) {
      _ephemeralContent.putIfAbsent(contentId, () => []).add(content);
    }
    
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
    
    // Clean up ephemeral content during compression
    _cleanupEphemeralContent();
    
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
  
  /// Mark content as ephemeral for future cleanup
  void markEphemeral(String contentId, String content, {int estimatedTokens = 100}) {
    addToContext(content, estimatedTokens: estimatedTokens, ephemeral: true, contentId: contentId);
  }
  
  /// Clean up ephemeral content by content ID
  void cleanupEphemeral(String contentId) {
    final removed = _ephemeralContent.remove(contentId);
    if (removed != null) {
      _estimatedTokens = (_estimatedTokens - (removed.length * 100)).clamp(0, maxContextTokens);
    }
  }
  
  /// Clean up all ephemeral content
  void _cleanupEphemeralContent() {
    final totalEphemeral = _ephemeralContent.values.fold<int>(0, (sum, list) => sum + list.length);
    _ephemeralContent.clear();
    _estimatedTokens = (_estimatedTokens - (totalEphemeral * 100)).clamp(0, maxContextTokens);
  }
  
  /// Track file reads for version management
  void trackFileRead(String filePath, String content) {
    // Clean up any previous versions of this file
    cleanupFileVersions(filePath);
    
    // Add current version as ephemeral
    markEphemeral('file:$filePath', content, estimatedTokens: estimateTokens(content));
    _currentFiles.add(filePath);
  }
  
  /// Clean up all versions of a file
  void cleanupFileVersions(String filePath) {
    cleanupEphemeral('file:$filePath');
    _currentFiles.remove(filePath);
  }
  
  /// Estimate tokens from text content
  int estimateTokens(String text) {
    // Simple estimation: ~4 characters per token
    return (text.length / 4).ceil();
  }
}

/// Create a new context manager with auto-generated session ID
ContextManager createContextManager() {
  final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  return ContextManager(sessionId, Directory.current.path);
}
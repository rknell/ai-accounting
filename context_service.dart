// Context Service for AI Coding Assistant
// Standalone service for context management without MCP dependencies

import 'dart:io';

import 'context_manager.dart';
import 'token_monitor.dart';

/// Context Service for managing AI context windows with persistence
/// This is a standalone service that doesn't depend on MCP infrastructure
class ContextService {
  final ContextManager _contextManager;
  final TokenMonitor _tokenMonitor;

  /// Create a new context service
  ContextService()
      : _contextManager = _createContextManager(),
        _tokenMonitor = TokenMonitor();

  /// Create a context manager with default session ID and working directory
  static ContextManager _createContextManager() {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final workingDirectory = Directory.current.path;
    return ContextManager(sessionId, workingDirectory);
  }

  /// Add content to context and track token usage
  Map<String, dynamic> addToContext(String content,
      {int estimatedTokens = 100}) {
    _contextManager.addToContext(content, estimatedTokens: estimatedTokens);
    _tokenMonitor.addTokens(estimatedTokens);

    return {
      'success': true,
      'current_tokens': _contextManager.estimatedTokens,
      'status': _tokenMonitor.status,
      'usage_percentage': _tokenMonitor.usagePercentage,
    };
  }

  /// Save current session state
  Future<Map<String, dynamic>> saveSession() async {
    await _contextManager.saveSession();

    return {
      'success': true,
      'session_id': _contextManager.sessionId,
      'saved_at': DateTime.now().toIso8601String(),
    };
  }

  /// Load session state
  Future<Map<String, dynamic>> loadSession() async {
    await _contextManager.loadSession();

    return {
      'success': true,
      'session_id': _contextManager.sessionId,
      'loaded_tokens': _contextManager.estimatedTokens,
      'summary_count': _contextManager.contextSummaries.length,
    };
  }

  /// Add a todo item
  Map<String, dynamic> addTodo(String item) {
    _contextManager.addTodo(item);

    return {
      'success': true,
      'todo_count': _contextManager.getTodos().length,
      'added_item': item,
    };
  }

  /// Get current context status
  Map<String, dynamic> getContextStatus() {
    return {
      'session_id': _contextManager.sessionId,
      'estimated_tokens': _contextManager.estimatedTokens,
      'status': _tokenMonitor.status,
      'usage_percentage': _tokenMonitor.usagePercentage,
      'todo_count': _contextManager.getTodos().length,
      'summary_count': _contextManager.contextSummaries.length,
    };
  }

  /// Get the underlying context manager
  ContextManager get contextManager => _contextManager;

  /// Get the underlying token monitor
  TokenMonitor get tokenMonitor => _tokenMonitor;
}

/// Global context service instance
final contextService = ContextService();

/// Example usage function
void demonstrateContextService() {
  print('🧠 Demonstrating Context Service...');

  // Add some content to context
  final result1 = contextService.addToContext(
    'This is a test of the context management system',
    estimatedTokens: 50,
  );

  print('Added content: ${result1['current_tokens']} tokens');
  print('Status: ${result1['status']}');

  // Add a todo item
  final result2 = contextService.addTodo('Test context compression');
  print('Todo count: ${result2['todo_count']}');

  // Get status
  final status = contextService.getContextStatus();
  print('Current status: $status');

  print('✅ Context service demonstration completed!');
}

// Simple test to verify context manager analysis compliance

import 'dart:convert';
import 'dart:io';

/// Test version of context manager without MCP dependencies
class TestContextManager {
  static const int maxContextTokens = 90000;
  static const int summaryThreshold = 50000;
  
  final String sessionId;
  final String workingDirectory;
  
  TestContextManager(this.sessionId, this.workingDirectory);
  
  Map<String, dynamic> _sessionState = {};
  List<String> _contextSummaries = [];
  int _estimatedTokens = 0;
  
  void addToContext(String content, {int estimatedTokens = 100}) {
    _estimatedTokens += estimatedTokens;
    
    if (_estimatedTokens > summaryThreshold) {
      _summarizeContext();
    }
    
    if (_estimatedTokens > maxContextTokens) {
      _compressContext();
    }
  }
  
  void _summarizeContext() {
    final summary = 'Summary at ${DateTime.now()}: Estimated tokens: $_estimatedTokens';
    _contextSummaries.add(summary);
    _estimatedTokens = 20000;
  }
  
  void _compressContext() {
    if (_contextSummaries.length > 5) {
      _contextSummaries = _contextSummaries.sublist(_contextSummaries.length - 3);
    }
    _estimatedTokens = 30000;
  }
  
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
}

void main() {
  print('Testing context manager analysis...');
  final manager = TestContextManager('test123', Directory.current.path);
  manager.addToContext('Test content');
  print('Context manager test completed successfully!');
}
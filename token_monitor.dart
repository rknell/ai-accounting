// Token Usage Monitor for Context Window Management

/// Monitors token usage for large language model context windows
/// with warning thresholds and status reporting
class TokenMonitor {
  /// Warning threshold for token usage
  static const int warningThreshold = 80000;
  
  /// Critical threshold for token usage
  static const int criticalThreshold = 95000;
  
  /// Current token count
  int _currentTokens = 0;
  
  /// History of token usage
  final List<int> _tokenHistory = [];
  
  /// Add tokens to the current count and check thresholds
  void addTokens(int count) {
    _currentTokens += count;
    _tokenHistory.add(_currentTokens);
    
    if (_currentTokens > warningThreshold) {
      print('⚠️  WARNING: Approaching context limit ($_currentTokens tokens)');
    }
    
    if (_currentTokens > criticalThreshold) {
      print('🚨 CRITICAL: Context window nearly full ($_currentTokens tokens)');
      _suggestCompression();
    }
  }
  
  /// Suggest compression strategies when nearing limit
  void _suggestCompression() {
    print('💡 Suggestion: Implement context summarization');
    print('💡 Consider: Saving session state and restarting');
  }
  
  /// Get current token count
  int get currentTokens => _currentTokens;
  
  /// Get token usage percentage (0-100)
  double get usagePercentage => (_currentTokens / 100000) * 100;
  
  /// Get current status based on token usage
  String get status {
    if (_currentTokens > criticalThreshold) return 'CRITICAL';
    if (_currentTokens > warningThreshold) return 'WARNING';
    return 'NORMAL';
  }
  
  /// Reset token counter and history
  void reset() {
    _currentTokens = 0;
    _tokenHistory.clear();
  }
  
  /// Get token history for analysis
  List<int> get tokenHistory => List<int>.from(_tokenHistory);
}

/// Utility function for estimating token count from text
int estimateTokens(String text) {
  // Simple estimation: ~4 characters per token
  return (text.length / 4).ceil();
}
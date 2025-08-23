// Comprehensive test for context management system

import 'dart:io';

import 'context_manager.dart';
import 'context_service.dart';
import 'token_monitor.dart';

void main() async {
  print('🧪 Comprehensive Context Management Test');
  print('=' * 50);
  
  // Test 1: Context Manager Basic Functionality
  print('\n1. Testing Context Manager...');
  final manager = ContextManager('test_session', '.');
  
  manager.addToContext('Initial test content');
  print('   Initial tokens: ${manager.estimatedTokens}');
  
  // Add more content to trigger summarization
  for (var i = 0; i < 10; i++) {
    manager.addToContext('Test content block $i', estimatedTokens: 1000);
  }
  print('   After adding content: ${manager.estimatedTokens} tokens');
  print('   Summaries: ${manager.contextSummaries.length}');
  
  // Test 2: Token Monitor
  print('\n2. Testing Token Monitor...');
  final monitor = TokenMonitor();
  
  monitor.addTokens(50000);
  print('   Status: ${monitor.status}');
  print('   Usage: ${monitor.usagePercentage.toStringAsFixed(1)}%');
  
  monitor.addTokens(40000);
  print('   Critical status: ${monitor.status}');
  
  // Test 3: Session Persistence
  print('\n3. Testing Session Persistence...');
  await manager.saveSession();
  print('   Session saved successfully');
  
  // Test 4: Todo System
  print('\n4. Testing Todo System...');
  manager.addTodo('Test task 1');
  manager.addTodo('Test task 2');
  
  final todos = manager.getTodos();
  print('   Todo count: ${todos.length}');
  print('   Todos: $todos');
  
  // Test 5: Context Service
  print('\n5. Testing Context Service...');
  final service = ContextService();
  
  final result = service.addToContext('Service test content', estimatedTokens: 200);
  print('   Service result: ${result['current_tokens']} tokens');
  
  // Test 6: Token Estimation
  print('\n6. Testing Token Estimation...');
  final testText = 'This is a test string for token estimation';
  final estimatedTokens = estimateTokens(testText);
  print('   Text: "$testText"');
  print('   Estimated tokens: $estimatedTokens');
  
  print('\n✅ All tests completed successfully!');
  print('\n📊 Final Status:');
  print('   Context Manager tokens: ${manager.estimatedTokens}');
  print('   Token Monitor status: ${monitor.status}');
  print('   Todo items: ${manager.getTodos().length}');
  
  // Clean up test session file
  final testFile = File('./session_test_session.json');
  if (await testFile.exists()) {
    await testFile.delete();
    print('\n🧹 Cleaned up test session file');
  }
}
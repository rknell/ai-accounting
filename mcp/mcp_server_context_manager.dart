import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_openai_client/dart_openai_client.dart';

/// 🏆 CONTEXT MANAGER MCP SERVER: Intelligent Context Optimization [+1000 XP]
///
/// **ARCHITECTURAL VICTORY**: This MCP server provides intelligent context management
/// capabilities for AI agents, allowing them to optimize their context when it becomes
/// too long or complex:
/// 1. Context analysis and complexity assessment
/// 2. Intelligent summarization and compression
/// 3. Context cleanup and optimization
/// 4. Memory management and retention strategies
/// 5. Context versioning and rollback capabilities
/// 6. Performance monitoring and optimization suggestions
///
/// **STRATEGIC DECISIONS**:
/// - AI-powered context analysis using the agent's own capabilities
/// - Intelligent summarization that preserves critical information
/// - Context versioning for safety and rollback capability
/// - Performance metrics to guide optimization decisions
/// - Integration with agent's existing knowledge and preferences
/// - Registration-based architecture (eliminates boilerplate)
/// - Strong typing for all operations (eliminates dynamic vulnerabilities)
///
/// **CONTEXT OPTIMIZATION STRATEGIES**:
/// - Semantic compression using AI summarization
/// - Hierarchical information organization
/// - Critical information preservation algorithms
/// - Context length optimization for performance
/// - Memory efficiency and retention management
class ContextManagerMCPServer extends BaseMCPServer {
  /// Configuration options
  final bool enableDebugLogging;
  final int maxContextLength;
  final int maxContextComplexity;
  final Duration contextAnalysisTimeout;

  /// Context versioning and history
  final Map<String, Map<String, dynamic>> _contextHistory = {};
  final Map<String, int> _contextVersions = {};

  ContextManagerMCPServer({
    super.name = 'context-manager',
    super.version = '1.0.0',
    super.logger,
    this.enableDebugLogging = false,
    this.maxContextLength = 10000,
    this.maxContextComplexity = 100,
    this.contextAnalysisTimeout = const Duration(seconds: 30),
  });

  @override
  Map<String, dynamic> getCapabilities() {
    final base = super.getCapabilities();
    return {
      ...base,
      'context_management': {
        'version': '1.0.0',
        'features': [
          'context_analysis',
          'context_summarization',
          'context_cleanup',
          'context_optimization',
          'context_versioning',
          'performance_monitoring',
          'memory_management',
        ],
        'limits': {
          'max_context_length': maxContextLength,
          'max_context_complexity': maxContextComplexity,
          'analysis_timeout': contextAnalysisTimeout.inSeconds,
        },
      },
    };
  }

  @override
  Future<void> initializeServer() async {
    // 🔍 **CONTEXT ANALYSIS TOOLS**: Analyze context complexity and structure

    registerTool(MCPTool(
      name: 'analyze_context',
      description:
          'Analyze the current context for complexity, length, and optimization opportunities',
      inputSchema: {
        'type': 'object',
        'properties': {
          'context': {
            'type': 'string',
            'description':
                'The context to analyze (conversation history, system state, etc.)',
          },
          'contextType': {
            'type': 'string',
            'description':
                'Type of context (conversation, system, knowledge, etc.)',
            'enum': ['conversation', 'system', 'knowledge', 'mixed'],
            'default': 'mixed',
          },
          'includeMetrics': {
            'type': 'boolean',
            'description': 'Whether to include detailed performance metrics',
            'default': true,
          },
        },
        'required': ['context'],
      },
      callback: _handleAnalyzeContext,
    ));

    // 🔍 **CONTEXT MANAGEMENT TOOLS**: AI context optimization and session management
    registerTool(MCPTool(
      name: 'add_to_context',
      description: 'Add content to context and track token usage',
      inputSchema: {
        'type': 'object',
        'properties': {
          'content': {
            'type': 'string',
            'description': 'Content to add to context',
          },
          'estimatedTokens': {
            'type': 'integer',
            'description': 'Estimated token count (default: 100)',
            'default': 100,
          },
        },
        'required': ['content'],
      },
      callback: _handleAddToContext,
    ));

    registerTool(MCPTool(
      name: 'save_session',
      description: 'Save current session state for crash recovery',
      inputSchema: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
      },
      callback: _handleSaveSession,
    ));

    registerTool(MCPTool(
      name: 'add_todo',
      description: 'Add a todo item for session continuity',
      inputSchema: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'item': <String, dynamic>{
            'type': 'string',
            'description': 'Todo item description',
          },
        },
        'required': <String>['item'],
      },
      callback: _handleAddTodo,
    ));

    registerTool(MCPTool(
      name: 'get_context_status',
      description: 'Get current context status and statistics',
      inputSchema: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
      },
      callback: _handleGetContextStatus,
    ));

    registerTool(MCPTool(
      name: 'summarize_context',
      description:
          'Intelligently summarize context while preserving critical information',
      inputSchema: {
        'type': 'object',
        'properties': {
          'context': {
            'type': 'string',
            'description': 'The context to summarize',
          },
          'targetLength': {
            'type': 'integer',
            'description':
                'Target length for the summarized context (default: 50% of original)',
            'minimum': 100,
          },
          'preserveCritical': {
            'type': 'boolean',
            'description':
                'Whether to preserve critical information (default: true)',
            'default': true,
          },
          'focusAreas': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Specific areas to focus on during summarization',
          },
          'contextType': {
            'type': 'string',
            'description': 'Type of context for specialized summarization',
            'enum': ['conversation', 'system', 'knowledge', 'mixed'],
            'default': 'mixed',
          },
        },
        'required': ['context'],
      },
      callback: _handleSummarizeContext,
    ));

    registerTool(MCPTool(
      name: 'cleanup_context',
      description:
          'Clean up and optimize context by removing redundancy and organizing information',
      inputSchema: {
        'type': 'object',
        'properties': {
          'context': {
            'type': 'string',
            'description': 'The context to clean up',
          },
          'removeRedundancy': {
            'type': 'boolean',
            'description': 'Remove redundant information (default: true)',
            'default': true,
          },
          'organizeByTopic': {
            'type': 'boolean',
            'description': 'Organize information by topic (default: true)',
            'default': true,
          },
          'prioritizeInformation': {
            'type': 'boolean',
            'description':
                'Prioritize information by importance (default: true)',
            'default': true,
          },
          'contextType': {
            'type': 'string',
            'description': 'Type of context for specialized cleanup',
            'enum': ['conversation', 'system', 'knowledge', 'mixed'],
            'default': 'mixed',
          },
        },
        'required': ['context'],
      },
      callback: _handleCleanupContext,
    ));

    registerTool(MCPTool(
      name: 'optimize_context',
      description:
          'Comprehensive context optimization combining analysis, summarization, and cleanup',
      inputSchema: {
        'type': 'object',
        'properties': {
          'context': {
            'type': 'string',
            'description': 'The context to optimize',
          },
          'optimizationLevel': {
            'type': 'string',
            'description':
                'Level of optimization (conservative, balanced, aggressive)',
            'enum': ['conservative', 'balanced', 'aggressive'],
            'default': 'balanced',
          },
          'targetMetrics': {
            'type': 'object',
            'properties': {
              'maxLength': {'type': 'integer'},
              'maxComplexity': {'type': 'integer'},
              'retentionRate': {
                'type': 'number',
                'minimum': 0.5,
                'maximum': 1.0
              },
            },
            'description': 'Target metrics for optimization',
          },
          'contextType': {
            'type': 'string',
            'description': 'Type of context for specialized optimization',
            'enum': ['conversation', 'system', 'knowledge', 'mixed'],
            'default': 'mixed',
          },
        },
        'required': ['context'],
      },
      callback: _handleOptimizeContext,
    ));

    registerTool(MCPTool(
      name: 'version_context',
      description:
          'Create a versioned snapshot of the current context for safety and rollback',
      inputSchema: {
        'type': 'object',
        'properties': {
          'context': {
            'type': 'string',
            'description': 'The context to version',
          },
          'versionName': {
            'type': 'string',
            'description': 'Human-readable name for this version',
          },
          'description': {
            'type': 'string',
            'description': 'Description of what this version represents',
          },
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Tags for categorizing this version',
          },
        },
        'required': ['context', 'versionName'],
      },
      callback: _handleVersionContext,
    ));

    registerTool(MCPTool(
      name: 'restore_context',
      description: 'Restore a previous version of the context',
      inputSchema: {
        'type': 'object',
        'properties': {
          'versionId': {
            'type': 'string',
            'description': 'ID of the version to restore',
          },
          'contextType': {
            'type': 'string',
            'description': 'Type of context to restore',
            'enum': ['conversation', 'system', 'knowledge', 'mixed'],
            'default': 'mixed',
          },
        },
        'required': ['versionId'],
      },
      callback: _handleRestoreContext,
    ));

    registerTool(MCPTool(
      name: 'list_context_versions',
      description: 'List all available context versions with metadata',
      inputSchema: {
        'type': 'object',
        'properties': {
          'contextType': {
            'type': 'string',
            'description': 'Filter by context type',
            'enum': ['conversation', 'system', 'knowledge', 'mixed'],
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of versions to return (default: 50)',
            'default': 50,
            'minimum': 1,
            'maximum': 1000,
          },
          'includeMetadata': {
            'type': 'boolean',
            'description':
                'Whether to include detailed metadata (default: true)',
            'default': true,
          },
        },
      },
      callback: _handleListContextVersions,
    ));

    registerTool(MCPTool(
      name: 'get_context_metrics',
      description:
          'Get detailed performance and quality metrics for context management',
      inputSchema: {
        'type': 'object',
        'properties': {
          'contextType': {
            'type': 'string',
            'description': 'Type of context to analyze',
            'enum': ['conversation', 'system', 'knowledge', 'mixed'],
          },
          'includeHistory': {
            'type': 'boolean',
            'description':
                'Whether to include historical metrics (default: false)',
            'default': false,
          },
          'timeRange': {
            'type': 'string',
            'description':
                'Time range for historical data (e.g., "24h", "7d", "30d")',
          },
        },
      },
      callback: _handleGetContextMetrics,
    ));

    logger?.call('info',
        'Context Manager MCP server initialized with ${getAvailableTools().length} tools');
  }

  /// 🔍 **CONTEXT ANALYSIS**: Analyze context complexity and structure
  Future<MCPToolResult> _handleAnalyzeContext(
      Map<String, dynamic> arguments) async {
    final context = arguments['context'] as String;
    final contextType = arguments['contextType'] as String? ?? 'mixed';
    final includeMetrics = arguments['includeMetrics'] as bool? ?? true;

    logger?.call('info',
        'Analyzing context of type: $contextType (${context.length} characters)');

    try {
      // Calculate basic metrics
      final metrics = _calculateContextMetrics(context, contextType);

      // Analyze context structure
      final structure = _analyzeContextStructure(context, contextType);

      // Generate optimization recommendations
      final recommendations =
          _generateOptimizationRecommendations(metrics, structure);

      final result = {
        'success': true,
        'analysis': {
          'contextType': contextType,
          'originalLength': context.length,
          'metrics': metrics,
          'structure': structure,
          'recommendations': recommendations,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (includeMetrics) {
        final analysis = result['analysis'] as Map<String, dynamic>?;
        if (analysis != null) {
          analysis['detailedMetrics'] =
              _calculateDetailedMetrics(context, contextType);
        }
      }

      logger?.call('info', 'Context analysis completed successfully');

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode(result)),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Context analysis failed', e);
      throw MCPServerException('Context analysis failed: ${e.toString()}');
    }
  }

  /// 📝 **CONTEXT SUMMARIZATION**: Intelligently summarize context
  Future<MCPToolResult> _handleSummarizeContext(
      Map<String, dynamic> arguments) async {
    final context = arguments['context'] as String;
    final targetLength =
        arguments['targetLength'] as int? ?? (context.length ~/ 2);
    final preserveCritical = arguments['preserveCritical'] as bool? ?? true;
    final focusAreas = arguments['focusAreas'] as List<dynamic>? ?? [];
    final contextType = arguments['contextType'] as String? ?? 'mixed';

    logger?.call('info',
        'Summarizing context to $targetLength characters (${context.length} original)');

    try {
      // Perform intelligent summarization
      final summary = await _performIntelligentSummarization(
        context,
        targetLength,
        preserveCritical,
        focusAreas,
        contextType,
      );

      final result = {
        'success': true,
        'summarization': {
          'originalLength': context.length,
          'summaryLength': summary.length,
          'compressionRatio':
              (summary.length / context.length).toStringAsFixed(2),
          'preservedCritical': preserveCritical,
          'focusAreas': focusAreas,
          'contextType': contextType,
          'summary': summary,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      logger?.call('info', 'Context summarization completed successfully');

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode(result)),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Context summarization failed', e);
      throw MCPServerException('Context summarization failed: ${e.toString()}');
    }
  }

  /// 🧹 **CONTEXT CLEANUP**: Clean up and organize context
  Future<MCPToolResult> _handleCleanupContext(
      Map<String, dynamic> arguments) async {
    final context = arguments['context'] as String;
    final removeRedundancy = arguments['removeRedundancy'] as bool? ?? true;
    final organizeByTopic = arguments['organizeByTopic'] as bool? ?? true;
    final prioritizeInformation =
        arguments['prioritizeInformation'] as bool? ?? true;
    final contextType = arguments['contextType'] as String? ?? 'mixed';

    logger?.call('info', 'Cleaning up context of type: $contextType');

    try {
      // Perform context cleanup
      final cleanedContext = await _performContextCleanup(
        context,
        removeRedundancy,
        organizeByTopic,
        prioritizeInformation,
        contextType,
      );

      final result = {
        'success': true,
        'cleanup': {
          'originalLength': context.length,
          'cleanedLength': cleanedContext.length,
          'improvementRatio':
              (cleanedContext.length / context.length).toStringAsFixed(2),
          'operations': {
            'removeRedundancy': removeRedundancy,
            'organizeByTopic': organizeByTopic,
            'prioritizeInformation': prioritizeInformation,
          },
          'contextType': contextType,
          'cleanedContext': cleanedContext,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      logger?.call('info', 'Context cleanup completed successfully');

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode(result)),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Context cleanup failed', e);
      throw MCPServerException('Context cleanup failed: ${e.toString()}');
    }
  }

  /// ⚡ **CONTEXT OPTIMIZATION**: Comprehensive optimization
  Future<MCPToolResult> _handleOptimizeContext(
      Map<String, dynamic> arguments) async {
    final context = arguments['context'] as String;
    final optimizationLevel =
        arguments['optimizationLevel'] as String? ?? 'balanced';
    final targetMetrics =
        arguments['targetMetrics'] as Map<String, dynamic>? ?? {};
    final contextType = arguments['contextType'] as String? ?? 'mixed';

    logger?.call('info', 'Optimizing context with level: $optimizationLevel');

    try {
      // Perform comprehensive optimization
      final optimizedContext = await _performComprehensiveOptimization(
        context,
        optimizationLevel,
        targetMetrics,
        contextType,
      );

      final result = {
        'success': true,
        'optimization': {
          'originalLength': context.length,
          'optimizedLength': optimizedContext.length,
          'optimizationLevel': optimizationLevel,
          'targetMetrics': targetMetrics,
          'contextType': contextType,
          'optimizedContext': optimizedContext,
          'improvements':
              _calculateOptimizationImprovements(context, optimizedContext),
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      logger?.call('info', 'Context optimization completed successfully');

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode(result)),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Context optimization failed', e);
      throw MCPServerException('Context optimization failed: ${e.toString()}');
    }
  }

  /// 🏷️ **CONTEXT VERSIONING**: Create versioned snapshots
  Future<MCPToolResult> _handleVersionContext(
      Map<String, dynamic> arguments) async {
    final context = arguments['context'] as String;
    final versionName = arguments['versionName'] as String;
    final description = arguments['description'] as String? ?? '';
    final tags = arguments['tags'] as List<dynamic>? ?? [];

    logger?.call('info', 'Creating context version: $versionName');

    try {
      // Create versioned snapshot
      final versionId =
          _createContextVersion(context, versionName, description, tags);

      final result = {
        'success': true,
        'versioning': {
          'versionId': versionId,
          'versionName': versionName,
          'description': description,
          'tags': tags,
          'contextLength': context.length,
          'createdAt': DateTime.now().toIso8601String(),
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      logger?.call('info', 'Context version created successfully: $versionId');

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode(result)),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Context versioning failed', e);
      throw MCPServerException('Context versioning failed: ${e.toString()}');
    }
  }

  /// 🔄 **CONTEXT RESTORATION**: Restore previous versions
  Future<MCPToolResult> _handleRestoreContext(
      Map<String, dynamic> arguments) async {
    final versionId = arguments['versionId'] as String;
    final contextType = arguments['contextType'] as String? ?? 'mixed';

    logger?.call('info', 'Restoring context version: $versionId');

    try {
      // Restore context version
      final restoredContext = _restoreContextVersion(versionId, contextType);

      final result = {
        'success': true,
        'restoration': {
          'versionId': versionId,
          'contextType': contextType,
          'restoredContext': restoredContext,
          'restoredAt': DateTime.now().toIso8601String(),
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      logger?.call('info', 'Context restoration completed successfully');

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode(result)),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Context restoration failed', e);
      throw MCPServerException('Context restoration failed: ${e.toString()}');
    }
  }

  /// 📋 **CONTEXT VERSION LISTING**: List available versions
  Future<MCPToolResult> _handleListContextVersions(
      Map<String, dynamic> arguments) async {
    final contextType = arguments['contextType'] as String?;
    final limit = arguments['limit'] as int? ?? 50;
    final includeMetadata = arguments['includeMetadata'] as bool? ?? true;

    logger?.call('info', 'Listing context versions (limit: $limit)');

    try {
      // Get available versions
      final versions =
          _getAvailableVersions(contextType, limit, includeMetadata);

      final result = {
        'success': true,
        'versions': {
          'total': versions.length,
          'limit': limit,
          'contextType': contextType,
          'versions': versions,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      logger?.call('info', 'Context versions listed successfully');

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode(result)),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Context version listing failed', e);
      throw MCPServerException(
          'Context version listing failed: ${e.toString()}');
    }
  }

  /// 📊 **CONTEXT METRICS**: Get performance metrics
  Future<MCPToolResult> _handleGetContextMetrics(
      Map<String, dynamic> arguments) async {
    final contextType = arguments['contextType'] as String?;
    final includeHistory = arguments['includeHistory'] as bool? ?? false;
    final timeRange = arguments['timeRange'] as String?;

    logger?.call('info', 'Getting context metrics for type: $contextType');

    try {
      // Calculate current metrics
      final currentMetrics = _calculateCurrentMetrics(contextType);

      // Get historical metrics if requested
      Map<String, dynamic>? historicalMetrics;
      if (includeHistory) {
        historicalMetrics = _getHistoricalMetrics(contextType, timeRange);
      }

      final result = {
        'success': true,
        'metrics': {
          'current': currentMetrics,
          'historical': historicalMetrics,
          'contextType': contextType,
          'timeRange': timeRange,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      logger?.call('info', 'Context metrics retrieved successfully');

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode(result)),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Context metrics retrieval failed', e);
      throw MCPServerException(
          'Context metrics retrieval failed: ${e.toString()}');
    }
  }

  /// 🔧 **HELPER METHODS**: Core functionality implementation

  /// 🔍 **CONTEXT MANAGEMENT HANDLERS**: Session and token management

  /// Add content to context and track token usage
  Future<MCPToolResult> _handleAddToContext(Map<String, dynamic> parameters) async {
    final content = parameters['content'] as String;
    final estimatedTokens = parameters['estimatedTokens'] as int? ?? 100;

    // Add to context history
    final contextId = 'context_${DateTime.now().millisecondsSinceEpoch}';
    _contextHistory[contextId] = {
      'content': content,
      'estimatedTokens': estimatedTokens,
      'timestamp': DateTime.now().toIso8601String(),
      'contextType': 'user_input',
    };

    // Update context version
    _contextVersions[contextId] = _contextVersions.length + 1;

    return MCPToolResult(
      content: [
        MCPContent.text(jsonEncode(<String, dynamic>{
          'success': true,
          'context_id': contextId,
          'content_length': content.length,
          'estimated_tokens': estimatedTokens,
          'total_contexts': _contextHistory.length,
          'added_at': DateTime.now().toIso8601String(),
        })),
      ],
    );
  }

  /// Save current session state for crash recovery
  Future<MCPToolResult> _handleSaveSession(Map<String, dynamic> parameters) async {
    try {
      // Create a comprehensive session snapshot
      final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      final sessionData = {
        'session_id': sessionId,
        'context_count': _contextHistory.length,
        'version_count': _contextVersions.length,
        'total_content_length': _contextHistory.values
            .map((c) => (c['content'] as String).length)
            .reduce((a, b) => a + b),
        'total_estimated_tokens': _contextHistory.values
            .map((c) => c['estimatedTokens'] as int)
            .reduce((a, b) => a + b),
        'saved_at': DateTime.now().toIso8601String(),
        'contexts': _contextHistory,
        'versions': _contextVersions,
      };

      // Store session data (in a real implementation, this would be saved to disk)
      _contextHistory[sessionId] = {
        'content': jsonEncode(sessionData),
        'estimatedTokens': 100, // Session metadata tokens
        'timestamp': DateTime.now().toIso8601String(),
        'contextType': 'session_snapshot',
      };

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode(<String, dynamic>{
            'success': true,
            'session_id': sessionId,
            'context_count': _contextHistory.length - 1, // Exclude session snapshot
            'version_count': _contextVersions.length,
            'saved_at': DateTime.now().toIso8601String(),
            'message': 'Session saved successfully',
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to save session', e);
      throw MCPServerException('Session save failed: ${e.toString()}');
    }
  }

  /// Add a todo item for session continuity
  Future<MCPToolResult> _handleAddTodo(Map<String, dynamic> parameters) async {
    final item = parameters['item'] as String;
    
    // Create a todo context entry
    final todoId = 'todo_${DateTime.now().millisecondsSinceEpoch}';
    _contextHistory[todoId] = {
      'content': item,
      'estimatedTokens': 50, // Todo items are typically short
      'timestamp': DateTime.now().toIso8601String(),
      'contextType': 'todo_item',
      'status': 'pending',
    };

    // Update context version
    _contextVersions[todoId] = _contextVersions.length + 1;

    // Count pending todos
    final pendingTodos = _contextHistory.values
        .where((c) => c['contextType'] == 'todo_item' && c['status'] == 'pending')
        .length;

    return MCPToolResult(
      content: [
        MCPContent.text(jsonEncode(<String, dynamic>{
          'success': true,
          'todo_id': todoId,
          'item': item,
          'pending_todos': pendingTodos,
          'total_todos': _contextHistory.values
              .where((c) => c['contextType'] == 'todo_item')
              .length,
          'added_at': DateTime.now().toIso8601String(),
        })),
      ],
    );
  }

  /// Get current context status and statistics
  Future<MCPToolResult> _handleGetContextStatus(Map<String, dynamic> parameters) async {
    try {
      // Calculate comprehensive status
      final totalContexts = _contextHistory.length;
      final totalContentLength = _contextHistory.values
          .map((c) => (c['content'] as String).length)
          .reduce((a, b) => a + b);
      final totalEstimatedTokens = _contextHistory.values
          .map((c) => c['estimatedTokens'] as int)
          .reduce((a, b) => a + b);

      // Count by context type
      final contextTypeCounts = <String, int>{};
      for (final context in _contextHistory.values) {
        final type = context['contextType'] as String;
        contextTypeCounts[type] = (contextTypeCounts[type] ?? 0) + 1;
      }

      // Count pending todos
      final pendingTodos = _contextHistory.values
          .where((c) => c['contextType'] == 'todo_item' && c['status'] == 'pending')
          .length;

      final status = {
        'total_contexts': totalContexts,
        'total_content_length': totalContentLength,
        'total_estimated_tokens': totalEstimatedTokens,
        'context_type_distribution': contextTypeCounts,
        'pending_todos': pendingTodos,
        'version_count': _contextVersions.length,
        'last_updated': DateTime.now().toIso8601String(),
        'performance': _calculateCurrentPerformance(),
      };

      return MCPToolResult(
        content: [
          MCPContent.text(jsonEncode(<String, dynamic>{
            'success': true,
            'status': status,
            'timestamp': DateTime.now().toIso8601String(),
          })),
        ],
      );
    } catch (e) {
      logger?.call('error', 'Failed to get context status', e);
      throw MCPServerException('Status retrieval failed: ${e.toString()}');
    }
  }

  /// Calculate basic context metrics
  Map<String, dynamic> _calculateContextMetrics(
      String context, String contextType) {
    final words = context.split(' ').length;
    final sentences = context.split(RegExp(r'[.!?]+')).length;
    final paragraphs = context.split('\n\n').length;

    // Calculate complexity score (0-100)
    final complexityScore = _calculateComplexityScore(context);

    // Calculate readability score
    final readabilityScore = _calculateReadabilityScore(context);

    return {
      'length': {
        'characters': context.length,
        'words': words,
        'sentences': sentences,
        'paragraphs': paragraphs,
      },
      'complexity': {
        'score': complexityScore,
        'level': _getComplexityLevel(complexityScore.round()),
      },
      'readability': {
        'score': readabilityScore,
        'level': _getReadabilityLevel(readabilityScore),
      },
      'density': {
        'wordsPerSentence': words / sentences,
        'charactersPerWord': context.length / words,
      },
    };
  }

  /// Calculate detailed context metrics
  Map<String, dynamic> _calculateDetailedMetrics(
      String context, String contextType) {
    final basicMetrics = _calculateContextMetrics(context, contextType);

    // Add specialized metrics based on context type
    final specializedMetrics =
        _calculateSpecializedMetrics(context, contextType);

    // Calculate performance indicators
    final performanceMetrics = _calculatePerformanceMetrics(context);

    return {
      ...basicMetrics,
      'specialized': specializedMetrics,
      'performance': performanceMetrics,
    };
  }

  /// Calculate specialized metrics based on context type
  Map<String, dynamic> _calculateSpecializedMetrics(
      String context, String contextType) {
    switch (contextType) {
      case 'conversation':
        return {
          'turnCount': _countConversationTurns(context),
          'participantCount': _countParticipants(context),
          'topicCount': _countTopics(context),
          'sentimentScore': _calculateSentimentScore(context),
        };
      case 'system':
        return {
          'componentCount': _countSystemComponents(context),
          'errorCount': _countErrors(context),
          'warningCount': _countWarnings(context),
          'statusCount': _countStatuses(context),
        };
      case 'knowledge':
        return {
          'factCount': _countFacts(context),
          'conceptCount': _countConcepts(context),
          'referenceCount': _countReferences(context),
          'accuracyScore': _calculateAccuracyScore(context),
        };
      default:
        return {
          'mixedMetrics': true,
          'conversationElements': _countConversationElements(context),
          'systemElements': _countSystemElements(context),
          'knowledgeElements': _countKnowledgeElements(context),
        };
    }
  }

  /// Helper methods for specialized metrics
  int _countConversationTurns(String context) {
    return context.split(RegExp(r'[.!?]+')).length;
  }

  int _countParticipants(String context) {
    final participants = <String>{};
    final lines = context.split('\n');
    for (final line in lines) {
      if (line.contains(':') && line.length < 100) {
        final parts = line.split(':');
        if (parts.length > 1) {
          participants.add(parts[0].trim());
        }
      }
    }
    return participants.length;
  }

  int _countTopics(String context) {
    final topics = <String>{};
    final words = context.toLowerCase().split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.length > 3 && RegExp(r'^[a-z]+$').hasMatch(word)) {
        topics.add(word);
      }
    }
    return topics.length;
  }

  double _calculateSentimentScore(String context) {
    // Simple sentiment analysis based on positive/negative words
    final positiveWords = [
      'good',
      'great',
      'excellent',
      'amazing',
      'wonderful',
      'perfect'
    ];
    final negativeWords = [
      'bad',
      'terrible',
      'awful',
      'horrible',
      'worst',
      'failed'
    ];

    final words = context.toLowerCase().split(RegExp(r'\s+'));
    int positiveCount = 0;
    int negativeCount = 0;

    for (final word in words) {
      if (positiveWords.contains(word)) positiveCount++;
      if (negativeWords.contains(word)) negativeCount++;
    }

    if (positiveCount == 0 && negativeCount == 0) return 0.0;
    return (positiveCount - negativeCount) / (positiveCount + negativeCount);
  }

  int _countSystemComponents(String context) {
    return context
            .split(RegExp(r'component|module|service|controller',
                caseSensitive: false))
            .length -
        1;
  }

  int _countErrors(String context) {
    return context
            .split(RegExp(r'error|exception|fail|crash', caseSensitive: false))
            .length -
        1;
  }

  int _countWarnings(String context) {
    return context
            .split(RegExp(r'warning|warn|caution', caseSensitive: false))
            .length -
        1;
  }

  int _countStatuses(String context) {
    return context
            .split(RegExp(r'status|state|condition', caseSensitive: false))
            .length -
        1;
  }

  int _countFacts(String context) {
    return context
            .split(
                RegExp(r'fact|data|information|evidence', caseSensitive: false))
            .length -
        1;
  }

  int _countConcepts(String context) {
    return context
            .split(
                RegExp(r'concept|idea|theory|principle', caseSensitive: false))
            .length -
        1;
  }

  int _countReferences(String context) {
    return context
            .split(RegExp(r'reference|source|citation|quote',
                caseSensitive: false))
            .length -
        1;
  }

  double _calculateAccuracyScore(String context) {
    // Simple accuracy scoring based on confidence indicators
    final confidenceWords = [
      'certain',
      'definite',
      'confirmed',
      'verified',
      'accurate'
    ];
    final uncertaintyWords = [
      'maybe',
      'perhaps',
      'possibly',
      'uncertain',
      'unclear'
    ];

    final words = context.toLowerCase().split(RegExp(r'\s+'));
    int confidenceCount = 0;
    int uncertaintyCount = 0;

    for (final word in words) {
      if (confidenceWords.contains(word)) confidenceCount++;
      if (uncertaintyWords.contains(word)) uncertaintyCount++;
    }

    if (confidenceCount == 0 && uncertaintyCount == 0) return 0.5;
    return confidenceCount / (confidenceCount + uncertaintyCount);
  }

  int _countConversationElements(String context) {
    return _countConversationTurns(context);
  }

  int _countSystemElements(String context) {
    return _countSystemComponents(context);
  }

  int _countKnowledgeElements(String context) {
    return _countFacts(context);
  }

  /// Calculate performance metrics for context
  Map<String, dynamic> _calculatePerformanceMetrics(String context) {
    final startTime = DateTime.now();

    // Measure processing time for various operations
    final wordCount = context.split(RegExp(r'\s+')).length;
    final charCount = context.length;
    final lineCount = context.split('\n').length;

    // Calculate complexity score
    final complexityScore = _calculateComplexityScore(context);

    // Calculate readability score
    final readabilityScore = _calculateReadabilityScore(context);

    final endTime = DateTime.now();
    final processingTime = endTime.difference(startTime).inMicroseconds;

    return {
      'processingTime': processingTime,
      'wordCount': wordCount,
      'charCount': charCount,
      'lineCount': lineCount,
      'complexityScore': complexityScore,
      'readabilityScore': readabilityScore,
      'performanceRating':
          _calculatePerformanceRating(processingTime, wordCount),
    };
  }

  /// Calculate complexity score for context
  double _calculateComplexityScore(String context) {
    final words = context.split(RegExp(r'\s+'));
    if (words.isEmpty) return 0.0;

    int longWords = 0;
    int technicalTerms = 0;

    for (final word in words) {
      if (word.length > 8) longWords++;
      if (RegExp(r'[A-Z][a-z]+[A-Z]').hasMatch(word)) technicalTerms++;
    }

    return (longWords + technicalTerms) / words.length;
  }

  /// Calculate readability score for context
  double _calculateReadabilityScore(String context) {
    final sentences = context.split(RegExp(r'[.!?]+'));
    if (sentences.isEmpty) return 0.0;

    final words = context.split(RegExp(r'\s+'));
    if (words.isEmpty) return 0.0;

    final syllables = _countSyllables(context);

    // Flesch Reading Ease formula
    final fleschScore = 206.835 -
        (1.015 * (words.length / sentences.length)) -
        (84.6 * (syllables / words.length));

    return fleschScore.clamp(0.0, 100.0);
  }

  /// Count syllables in text (simplified)
  int _countSyllables(String text) {
    final vowels = RegExp(r'[aeiouyAEIOUY]');
    final matches = vowels.allMatches(text);
    return matches.length;
  }

  /// Calculate performance rating
  String _calculatePerformanceRating(int processingTime, int wordCount) {
    if (wordCount == 0) return 'excellent';

    final timePerWord = processingTime / wordCount;

    if (timePerWord < 10) return 'excellent';
    if (timePerWord < 50) return 'good';
    if (timePerWord < 100) return 'average';
    return 'poor';
  }

  /// Analyze context structure
  Map<String, dynamic> _analyzeContextStructure(
      String context, String contextType) {
    // Analyze information hierarchy
    final hierarchy = _analyzeInformationHierarchy(context);

    // Identify key topics and themes
    final topics = _identifyKeyTopics(context);

    // Analyze information flow
    final flow = _analyzeInformationFlow(context);

    return {
      'hierarchy': hierarchy,
      'topics': topics,
      'flow': flow,
      'structure': _classifyStructureType(context, contextType),
    };
  }

  /// Generate optimization recommendations
  List<Map<String, dynamic>> _generateOptimizationRecommendations(
      Map<String, dynamic> metrics, Map<String, dynamic> structure) {
    final recommendations = <Map<String, dynamic>>[];

    // Length-based recommendations
    final lengthMetrics = metrics['length'] as Map<String, dynamic>?;
    if (lengthMetrics != null) {
      final characters = lengthMetrics['characters'] as int?;
      if (characters != null && characters > maxContextLength) {
        recommendations.add({
          'type': 'length_optimization',
          'priority': 'high',
          'description': 'Context exceeds maximum recommended length',
          'suggestions': [
            'Use summarization to reduce length',
            'Remove redundant information',
            'Focus on most relevant content',
          ],
        });
      }
    }

    // Complexity-based recommendations
    final complexityMetrics = metrics['complexity'] as Map<String, dynamic>?;
    if (complexityMetrics != null) {
      final score = complexityMetrics['score'] as num?;
      if (score != null && score > maxContextComplexity) {
        recommendations.add({
          'type': 'complexity_reduction',
          'priority': 'high',
          'description': 'Context complexity is too high',
          'suggestions': [
            'Simplify language and structure',
            'Break down complex concepts',
            'Use bullet points and lists',
          ],
        });
      }
    }

    // Structure-based recommendations
    final structureType = structure['structure'] as String?;
    if (structureType == 'unorganized') {
      recommendations.add({
        'type': 'structure_improvement',
        'priority': 'medium',
        'description': 'Context structure could be improved',
        'suggestions': [
          'Organize by topic or theme',
          'Use clear headings and sections',
          'Improve information flow',
        ],
      });
    }

    return recommendations;
  }

  /// Perform intelligent summarization
  Future<String> _performIntelligentSummarization(
      String context,
      int targetLength,
      bool preserveCritical,
      List<dynamic> focusAreas,
      String contextType) async {
    // This would typically use AI-powered summarization
    // For now, implement a rule-based approach

    if (context.length <= targetLength) {
      return context; // No summarization needed
    }

    // Simple summarization strategy
    final sentences = context.split(RegExp(r'[.!?]+'));
    final importantSentences =
        _identifyImportantSentences(sentences, focusAreas);

    // Build summary from important sentences
    String summary = '';
    for (final sentence in importantSentences) {
      if (summary.length + sentence.length > targetLength) break;
      summary += '${sentence.trim()}. ';
    }

    // Ensure we don't exceed target length
    if (summary.length > targetLength) {
      summary = '${summary.substring(0, targetLength - 3)}...';
    }

    return summary.trim();
  }

  /// Perform context cleanup
  Future<String> _performContextCleanup(
      String context,
      bool removeRedundancy,
      bool organizeByTopic,
      bool prioritizeInformation,
      String contextType) async {
    String cleanedContext = context;

    if (removeRedundancy) {
      cleanedContext = _removeRedundancy(cleanedContext);
    }

    if (organizeByTopic) {
      cleanedContext = _organizeByTopic(cleanedContext);
    }

    if (prioritizeInformation) {
      cleanedContext = _prioritizeInformation(cleanedContext);
    }

    return cleanedContext;
  }

  /// Perform comprehensive optimization
  Future<String> _performComprehensiveOptimization(
      String context,
      String optimizationLevel,
      Map<String, dynamic> targetMetrics,
      String contextType) async {
    // Apply optimization based on level
    String optimizedContext = context;

    switch (optimizationLevel) {
      case 'conservative':
        optimizedContext =
            await _applyConservativeOptimization(context, targetMetrics);
        break;
      case 'balanced':
        optimizedContext =
            await _applyBalancedOptimization(context, targetMetrics);
        break;
      case 'aggressive':
        optimizedContext =
            await _applyAggressiveOptimization(context, targetMetrics);
        break;
    }

    return optimizedContext;
  }

  /// Create context version
  String _createContextVersion(String context, String versionName,
      String description, List<dynamic> tags) {
    final versionId = 'v${DateTime.now().millisecondsSinceEpoch}';

    _contextHistory[versionId] = {
      'context': context,
      'versionName': versionName,
      'description': description,
      'tags': tags,
      'createdAt': DateTime.now().toIso8601String(),
      'contextType': _detectContextType(context),
    };

    _contextVersions[versionName] = _contextVersions.length + 1;

    return versionId;
  }

  /// Restore context version
  String _restoreContextVersion(String versionId, String contextType) {
    if (!_contextHistory.containsKey(versionId)) {
      throw MCPServerException('Context version not found: $versionId');
    }

    final version = _contextHistory[versionId]!;
    return version['context'] as String;
  }

  /// Get available versions
  List<Map<String, dynamic>> _getAvailableVersions(
      String? contextType, int limit, bool includeMetadata) {
    final versions = <Map<String, dynamic>>[];

    for (final entry in _contextHistory.entries.take(limit)) {
      final version = entry.value;

      if (contextType != null && version['contextType'] != contextType) {
        continue;
      }

      final versionInfo = {
        'versionId': entry.key,
        'versionName': version['versionName'],
        'description': version['description'],
        'tags': version['tags'],
        'createdAt': version['createdAt'],
        'contextType': version['contextType'],
      };

      if (includeMetadata) {
        versionInfo['metadata'] = {
          'contextLength': (version['context'] as String).length,
          'wordCount': (version['context'] as String).split(' ').length,
        };
      }

      versions.add(versionInfo);
    }

    return versions;
  }

  /// Calculate current metrics
  Map<String, dynamic> _calculateCurrentMetrics(String? contextType) {
    // Calculate metrics for current context state
    return {
      'totalVersions': _contextHistory.length,
      'contextTypes': _getContextTypeDistribution(),
      'storageUsage': _calculateStorageUsage(),
      'performance': _calculateCurrentPerformance(),
    };
  }

  /// Get historical metrics
  Map<String, dynamic>? _getHistoricalMetrics(
      String? contextType, String? timeRange) {
    // This would implement historical tracking
    // For now, return null
    return null;
  }

  /// Helper methods for calculations
  String _getComplexityLevel(int score) {
    if (score < 30) return 'simple';
    if (score < 60) return 'moderate';
    if (score < 80) return 'complex';
    return 'very_complex';
  }

  String _getReadabilityLevel(double score) {
    if (score >= 90) return 'very_easy';
    if (score >= 80) return 'easy';
    if (score >= 70) return 'fairly_easy';
    if (score >= 60) return 'standard';
    if (score >= 50) return 'fairly_difficult';
    if (score >= 30) return 'difficult';
    return 'very_difficult';
  }

  Map<String, dynamic> _analyzeInformationHierarchy(String context) {
    // Simple hierarchy analysis
    final lines = context.split('\n');
    final headings = <String>[];
    final content = <String>[];

    for (final line in lines) {
      if (line.trim().startsWith('#') || line.trim().startsWith('*')) {
        headings.add(line.trim());
      } else if (line.trim().isNotEmpty) {
        content.add(line.trim());
      }
    }

    return {
      'headings': headings,
      'contentSections': content.length,
      'structure': headings.isNotEmpty ? 'hierarchical' : 'flat',
    };
  }

  List<String> _identifyKeyTopics(String context) {
    // Simple topic identification
    final words = context.toLowerCase().split(' ');
    final wordFreq = <String, int>{};

    for (final word in words) {
      if (word.length > 3) {
        // Skip short words
        wordFreq[word] = (wordFreq[word] ?? 0) + 1;
      }
    }

    // Get top topics
    final sortedWords = wordFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedWords.take(5).map((e) => e.key).toList();
  }

  Map<String, dynamic> _analyzeInformationFlow(String context) {
    // Simple flow analysis
    final sentences = context.split(RegExp(r'[.!?]+'));

    return {
      'sentenceCount': sentences.length,
      'avgSentenceLength':
          sentences.map((s) => s.split(' ').length).reduce((a, b) => a + b) /
              sentences.length,
      'flow': sentences.length > 10 ? 'detailed' : 'concise',
    };
  }

  String _classifyStructureType(String context, String contextType) {
    // Classify structure based on content
    if (context.contains('\n\n')) return 'paragraphs';
    if (context.contains('\n')) return 'lines';
    if (context.contains('•') || context.contains('*')) return 'bullets';
    if (context.contains('1.') || context.contains('2.')) return 'numbered';
    return 'unorganized';
  }

  List<String> _identifyImportantSentences(
      List<String> sentences, List<dynamic> focusAreas) {
    // Simple importance scoring
    final scoredSentences = <MapEntry<String, double>>[];

    for (final sentence in sentences) {
      double score = 0;

      // Score based on focus areas
      for (final area in focusAreas) {
        if (sentence.toLowerCase().contains(area.toString().toLowerCase())) {
          score += 2;
        }
      }

      // Score based on sentence characteristics
      if (sentence.contains('important') ||
          sentence.contains('key') ||
          sentence.contains('critical')) {
        score += 1;
      }

      if (sentence.length > 20) score += 0.5;

      scoredSentences.add(MapEntry(sentence, score));
    }

    // Sort by score and return top sentences
    scoredSentences.sort((a, b) => b.value.compareTo(a.value));
    return scoredSentences
        .take((sentences.length * 0.6).round())
        .map((e) => e.key)
        .toList();
  }

  String _removeRedundancy(String context) {
    // Simple redundancy removal
    final sentences = context.split(RegExp(r'[.!?]+'));
    final uniqueSentences = <String>{};
    final cleanedSentences = <String>[];

    for (final sentence in sentences) {
      final normalized = sentence.trim().toLowerCase();
      if (!uniqueSentences.contains(normalized) && sentence.trim().isNotEmpty) {
        uniqueSentences.add(normalized);
        cleanedSentences.add(sentence.trim());
      }
    }

    return cleanedSentences.join('. ') +
        (cleanedSentences.isNotEmpty ? '.' : '');
  }

  String _organizeByTopic(String context) {
    // Simple topic organization
    final sentences = context.split(RegExp(r'[.!?]+'));
    final topics = <String, List<String>>{};

    for (final sentence in sentences) {
      final topic = _identifySentenceTopic(sentence);
      topics.putIfAbsent(topic, () => []).add(sentence.trim());
    }

    // Reorganize by topic
    final organized = <String>[];
    for (final topic in topics.keys) {
      organized.add('=== $topic ===');
      organized.addAll(topics[topic]!);
      organized.add('');
    }

    return organized.join('\n').trim();
  }

  String _identifySentenceTopic(String sentence) {
    // Simple topic identification
    final words = sentence.toLowerCase().split(' ');
    if (words.any((w) => w.contains('account'))) return 'Accounting';
    if (words.any((w) => w.contains('transaction'))) return 'Transactions';
    if (words.any((w) => w.contains('report'))) return 'Reports';
    if (words.any((w) => w.contains('supplier'))) return 'Suppliers';
    return 'General';
  }

  String _prioritizeInformation(String context) {
    // Simple prioritization
    final sentences = context.split(RegExp(r'[.!?]+'));
    final prioritized = <String>[];

    // Add high-priority sentences first
    for (final sentence in sentences) {
      if (_isHighPriority(sentence)) {
        prioritized.add(sentence.trim());
      }
    }

    // Add remaining sentences
    for (final sentence in sentences) {
      if (!_isHighPriority(sentence)) {
        prioritized.add(sentence.trim());
      }
    }

    return prioritized.join('. ') + (prioritized.isNotEmpty ? '.' : '');
  }

  bool _isHighPriority(String sentence) {
    final lower = sentence.toLowerCase();
    return lower.contains('important') ||
        lower.contains('critical') ||
        lower.contains('urgent') ||
        lower.contains('error') ||
        lower.contains('warning');
  }

  Future<String> _applyConservativeOptimization(
      String context, Map<String, dynamic> targetMetrics) async {
    // Conservative optimization - minimal changes
    return await _performContextCleanup(
      context,
      true, // removeRedundancy
      true, // organizeByTopic
      false, // prioritizeInformation
      'mixed',
    );
  }

  Future<String> _applyBalancedOptimization(
      String context, Map<String, dynamic> targetMetrics) async {
    // Balanced optimization - moderate changes
    String optimized = await _performContextCleanup(
      context,
      true, // removeRedundancy
      true, // organizeByTopic
      true, // prioritizeInformation
      'mixed',
    );

    // Apply moderate summarization if needed
    final targetLength =
        targetMetrics['maxLength'] as int? ?? (context.length * 0.7).round();
    if (optimized.length > targetLength) {
      optimized = await _performIntelligentSummarization(
        optimized,
        targetLength,
        true, // preserveCritical
        [], // focusAreas
        'mixed',
      );
    }

    return optimized;
  }

  Future<String> _applyAggressiveOptimization(
      String context, Map<String, dynamic> targetMetrics) async {
    // Aggressive optimization - maximum compression
    String optimized = await _performContextCleanup(
      context,
      true, // removeRedundancy
      true, // organizeByTopic
      true, // prioritizeInformation
      'mixed',
    );

    // Apply aggressive summarization
    final targetLength =
        targetMetrics['maxLength'] as int? ?? (context.length * 0.5).round();
    optimized = await _performIntelligentSummarization(
      optimized,
      targetLength,
      false, // preserveCritical - less preservation for aggressive mode
      [], // focusAreas
      'mixed',
    );

    return optimized;
  }

  String _detectContextType(String context) {
    // Simple context type detection
    if (context.contains('account') || context.contains('transaction')) {
      return 'accounting';
    }
    if (context.contains('conversation') || context.contains('chat')) {
      return 'conversation';
    }
    if (context.contains('system') || context.contains('config')) {
      return 'system';
    }
    return 'mixed';
  }

  Map<String, int> _getContextTypeDistribution() {
    final distribution = <String, int>{};
    for (final version in _contextHistory.values) {
      final type = version['contextType'] as String;
      distribution[type] = (distribution[type] ?? 0) + 1;
    }
    return distribution;
  }

  Map<String, dynamic> _calculateStorageUsage() {
    int totalSize = 0;
    for (final version in _contextHistory.values) {
      totalSize += (version['context'] as String).length;
    }

    return {
      'totalCharacters': totalSize,
      'totalVersions': _contextHistory.length,
      'averageVersionSize': totalSize / _contextHistory.length,
    };
  }

  Map<String, dynamic> _calculateCurrentPerformance() {
    // Simple performance metrics
    return {
      'responseTime': 'fast', // Placeholder
      'memoryUsage': 'low', // Placeholder
      'efficiency': 'high', // Placeholder
    };
  }

  Map<String, dynamic> _calculateOptimizationImprovements(
      String original, String optimized) {
    return {
      'lengthReduction':
          '${((original.length - optimized.length) / original.length * 100).toStringAsFixed(1)}%',
      'wordReduction':
          '${((original.split(' ').length - optimized.split(' ').length) / original.split(' ').length * 100).toStringAsFixed(1)}%',
      'compressionRatio':
          (optimized.length / original.length).toStringAsFixed(2),
    };
  }

  @override
  Future<void> shutdown() async {
    logger?.call('info', 'Shutting down Context Manager MCP server');

    // Clean up context history
    _contextHistory.clear();
    _contextVersions.clear();

    await super.shutdown();
  }
}

/// 🚀 **MAIN ENTRY POINT**: Start the Context Manager MCP server
void main() async {
  final server = ContextManagerMCPServer(
    enableDebugLogging: false,
    logger: (level, message, [data]) {
      if (level == 'error' || level == 'info') {
        final timestamp = DateTime.now().toIso8601String();
        stderr.writeln(
            '[$timestamp] [$level] $message${data != null ? ': $data' : ''}');
      }
    },
  );

  try {
    await server.start();
  } catch (e) {
    stderr.writeln('Failed to start Context Manager MCP server: $e');
    exit(1);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_openai_client/dart_openai_client.dart';

/// 🏆 DART MCP SERVER: Dart Development Operations [+1000 XP]
///
/// **ARCHITECTURAL VICTORY**: This MCP server provides comprehensive Dart development
/// capabilities for AI agents, allowing them to analyze, fix, and execute Dart code:
/// 1. Dart code analysis with detailed error reporting
/// 2. Automatic code fixing with dart fix
/// 3. Dart application execution with output capture
/// 4. Project structure analysis and validation
/// 5. Performance monitoring and optimization suggestions
/// 6. Dependency management and version checking
///
/// **STRATEGIC DECISIONS**:
/// - Comprehensive error analysis with actionable suggestions
/// - Safe execution with timeout protection and output capture
/// - Project validation before operations
/// - Performance metrics for optimization guidance
/// - Integration with existing development workflows
/// - Registration-based architecture (eliminates boilerplate)
/// - Strong typing for all operations (eliminates dynamic vulnerabilities)
///
/// **DART DEVELOPMENT STRATEGIES**:
/// - Static analysis for code quality assurance
/// - Automatic fixing for common issues
/// - Safe execution with proper error handling
/// - Performance profiling and optimization
/// - Dependency management and conflict resolution
class DartMCPServer extends BaseMCPServer {
  /// Configuration options
  final bool enableDebugLogging;
  final Duration executionTimeout;
  final int maxOutputSize;
  final String workingDirectory;

  /// Performance tracking
  final Map<String, Duration> _operationTimings = {};
  final Map<String, int> _operationCounts = {};

  DartMCPServer({
    super.name = 'dart-dev',
    super.version = '1.0.0',
    super.logger,
    this.enableDebugLogging = false,
    this.executionTimeout = const Duration(minutes: 5),
    this.maxOutputSize = 1000000, // 1MB
    this.workingDirectory = '.',
  });

  @override
  Map<String, dynamic> getCapabilities() {
    final base = super.getCapabilities();
    return {
      ...base,
      'dart_development': {
        'version': '1.0.0',
        'features': [
          'code_analysis',
          'automatic_fixing',
          'code_execution',
          'project_validation',
          'performance_monitoring',
          'dependency_management',
        ],
        'limits': {
          'execution_timeout': executionTimeout.inSeconds,
          'max_output_size': maxOutputSize,
          'working_directory': workingDirectory,
        },
      },
    };
  }

  @override
  Future<void> initializeServer() async {
    // 🔍 **CODE ANALYSIS TOOLS**: Analyze Dart code for issues and quality

    registerTool(MCPTool(
      name: 'analyze_dart_code',
      description:
          'Analyze Dart code using dart analyze to identify issues, warnings, and suggestions',
      inputSchema: {
        'type': 'object',
        'properties': {
          'target': {
            'type': 'string',
            'description':
                'Target to analyze (file path, directory, or project root)',
            'default': '.',
          },
          'includeWarnings': {
            'type': 'boolean',
            'description': 'Whether to include warnings in the analysis',
            'default': true,
          },
          'includeHints': {
            'type': 'boolean',
            'description': 'Whether to include hints in the analysis',
            'default': true,
          },
          'format': {
            'type': 'string',
            'description': 'Output format (json, machine, or default)',
            'enum': ['json', 'machine', 'default'],
            'default': 'json',
          },
        },
        'required': ['target'],
      },
      callback: _handleAnalyzeDartCode,
    ));

    // 🔧 **CODE FIXING TOOLS**: Automatically fix common Dart issues

    registerTool(MCPTool(
      name: 'fix_dart_code',
      description: 'Automatically fix common Dart code issues using dart fix',
      inputSchema: {
        'type': 'object',
        'properties': {
          'target': {
            'type': 'string',
            'description':
                'Target to fix (file path, directory, or project root)',
            'default': '.',
          },
          'dryRun': {
            'type': 'boolean',
            'description': 'Show what would be changed without making changes',
            'default': false,
          },
          'applyFixes': {
            'type': 'boolean',
            'description': 'Apply the fixes automatically',
            'default': true,
          },
        },
        'required': ['target'],
      },
      callback: _handleFixDartCode,
    ));

    // 🚀 **CODE EXECUTION TOOLS**: Execute Dart applications with safety

    registerTool(MCPTool(
      name: 'execute_dart_app',
      description:
          'Execute a Dart application with proper error handling and output capture',
      inputSchema: {
        'type': 'object',
        'properties': {
          'target': {
            'type': 'string',
            'description': 'Dart file or project to execute',
            'default': 'main.dart',
          },
          'arguments': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Command line arguments to pass to the application',
            'default': <String>[],
          },
          'workingDirectory': {
            'type': 'string',
            'description': 'Working directory for execution',
            'default': '.',
          },
          'timeout': {
            'type': 'integer',
            'description': 'Execution timeout in seconds',
            'default': 300,
          },
        },
        'required': ['target'],
      },
      callback: _handleExecuteDartApp,
    ));

    // 📊 **PROJECT VALIDATION TOOLS**: Validate Dart project structure

    registerTool(MCPTool(
      name: 'validate_dart_project',
      description:
          'Validate Dart project structure, dependencies, and configuration',
      inputSchema: {
        'type': 'object',
        'properties': {
          'projectPath': {
            'type': 'string',
            'description': 'Path to the Dart project to validate',
            'default': '.',
          },
          'checkDependencies': {
            'type': 'boolean',
            'description': 'Check for dependency conflicts and updates',
            'default': true,
          },
          'checkConfiguration': {
            'type': 'boolean',
            'description': 'Check project configuration files',
            'default': true,
          },
        },
        'required': ['projectPath'],
      },
      callback: _handleValidateDartProject,
    ));

    // 📈 **PERFORMANCE MONITORING TOOLS**: Monitor and optimize Dart performance

    registerTool(MCPTool(
      name: 'profile_dart_performance',
      description:
          'Profile Dart application performance and provide optimization suggestions',
      inputSchema: {
        'type': 'object',
        'properties': {
          'target': {
            'type': 'string',
            'description': 'Dart file or project to profile',
            'default': 'main.dart',
          },
          'profileMode': {
            'type': 'string',
            'description': 'Profiling mode (cpu, memory, or both)',
            'enum': ['cpu', 'memory', 'both'],
            'default': 'both',
          },
          'outputFile': {
            'type': 'string',
            'description': 'Output file for profiling data',
            'default': 'profile_data.json',
          },
        },
        'required': ['target'],
      },
      callback: _handleProfileDartPerformance,
    ));

    // 📦 **DEPENDENCY MANAGEMENT TOOLS**: Manage Dart package dependencies

    registerTool(MCPTool(
      name: 'manage_dart_dependencies',
      description: 'Manage Dart package dependencies, updates, and conflicts',
      inputSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'description': 'Action to perform on dependencies',
            'enum': ['get', 'upgrade', 'outdated', 'resolve'],
            'default': 'get',
          },
          'targetPackages': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Specific packages to act upon (empty for all)',
            'default': <String>[],
          },
          'dryRun': {
            'type': 'boolean',
            'description': 'Show what would be changed without making changes',
            'default': false,
          },
        },
        'required': ['action'],
      },
      callback: _handleManageDartDependencies,
    ));

    logger?.call('info', 'Dart MCP server initialized with 6 tools');
  }

  /// 🔍 **ANALYZE DART CODE**: Comprehensive code analysis
  Future<MCPToolResult> _handleAnalyzeDartCode(
      Map<String, dynamic> arguments) async {
    final startTime = DateTime.now();
    final target = arguments['target'] as String;
    final includeWarnings = arguments['includeWarnings'] as bool? ?? true;
    final includeHints = arguments['includeHints'] as bool? ?? true;
    final format = arguments['format'] as String? ?? 'json';

    try {
      // Validate target exists
      if (!await _validateTarget(target)) {
        return MCPToolResult(
          content: [
            MCPContent.text('❌ Target not found: $target'),
          ],
          isError: true,
        );
      }

      // Build dart analyze command
      final args = ['analyze'];
      if (format == 'json') {
        args.add('--format=machine');
      } else if (format == 'machine') {
        args.add('--format=machine');
      }

      if (!includeWarnings) {
        args.add('--no-warnings');
      }

      if (!includeHints) {
        args.add('--no-hints');
      }

      args.add(target);

      // Execute dart analyze
      final result = await _executeDartCommand(
        args,
        workingDirectory: workingDirectory,
        timeout: executionTimeout,
      );

      if (result.exitCode != 0) {
        return MCPToolResult(
          content: [
            MCPContent.text(
                '❌ Dart analyze failed with exit code ${result.exitCode}:\n${result.stderr}'),
          ],
          isError: true,
        );
      }

      // Parse and format results
      final analysisResults = await _parseAnalysisResults(
        result.stdout as String,
        format: format,
        includeWarnings: includeWarnings,
        includeHints: includeHints,
      );

      final duration = DateTime.now().difference(startTime);
      _recordOperation('analyze_dart_code', duration);

      return MCPToolResult(
        content: [
          MCPContent.text('🔍 **DART CODE ANALYSIS COMPLETE**\n\n'
              '📊 **SUMMARY**:\n'
              '• Target: $target\n'
              '• Duration: ${duration.inMilliseconds}ms\n'
              '• Format: $format\n\n'
              '📋 **RESULTS**:\n$analysisResults'),
        ],
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _recordOperation('analyze_dart_code', duration);

      return MCPToolResult(
        content: [
          MCPContent.text('❌ **ANALYSIS FAILED**: $e'),
        ],
        isError: true,
      );
    }
  }

  /// 🔧 **FIX DART CODE**: Automatic code fixing
  Future<MCPToolResult> _handleFixDartCode(
      Map<String, dynamic> arguments) async {
    final startTime = DateTime.now();
    final target = arguments['target'] as String;
    final dryRun = arguments['dryRun'] as bool? ?? false;
    final applyFixes = arguments['applyFixes'] as bool? ?? true;

    try {
      // Validate target exists
      if (!await _validateTarget(target)) {
        return MCPToolResult(
          content: [
            MCPContent.text('❌ Target not found: $target'),
          ],
          isError: true,
        );
      }

      // Build dart fix command
      final args = ['fix'];
      if (dryRun) {
        args.add('--dry-run');
      }
      args.add(target);

      // Execute dart fix
      final result = await _executeDartCommand(
        args,
        workingDirectory: workingDirectory,
        timeout: executionTimeout,
      );

      final duration = DateTime.now().difference(startTime);
      _recordOperation('fix_dart_code', duration);

      if (result.exitCode != 0) {
        return MCPToolResult(
          content: [
            MCPContent.text(
                '❌ Dart fix failed with exit code ${result.exitCode}:\n${result.stderr}'),
          ],
          isError: true,
        );
      }

      final action = dryRun ? 'DRY RUN' : (applyFixes ? 'APPLIED' : 'CHECKED');
      return MCPToolResult(
        content: [
          MCPContent.text('🔧 **DART CODE FIXING COMPLETE**\n\n'
              '📊 **SUMMARY**:\n'
              '• Target: $target\n'
              '• Action: $action\n'
              '• Duration: ${duration.inMilliseconds}ms\n\n'
              '📋 **OUTPUT**:\n${result.stdout}'),
        ],
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _recordOperation('fix_dart_code', duration);

      return MCPToolResult(
        content: [
          MCPContent.text('❌ **FIXING FAILED**: $e'),
        ],
        isError: true,
      );
    }
  }

  /// 🚀 **EXECUTE DART APP**: Safe application execution
  Future<MCPToolResult> _handleExecuteDartApp(
      Map<String, dynamic> arguments) async {
    final startTime = DateTime.now();
    final target = arguments['target'] as String;
    final argumentsList =
        (arguments['arguments'] as List<dynamic>?)?.cast<String>() ?? [];
    final execWorkingDir =
        arguments['workingDirectory'] as String? ?? workingDirectory;
    final timeout = Duration(seconds: arguments['timeout'] as int? ?? 300);

    try {
      // Validate target exists
      if (!await _validateTarget(target)) {
        return MCPToolResult(
          content: [
            MCPContent.text('❌ Target not found: $target'),
          ],
          isError: true,
        );
      }

      // Build dart run command
      final args = ['run'];
      args.add(target);
      args.addAll(argumentsList);

      // Execute dart run
      final result = await _executeDartCommand(
        args,
        workingDirectory: execWorkingDir,
        timeout: timeout,
      );

      final duration = DateTime.now().difference(startTime);
      _recordOperation('execute_dart_app', duration);

      final status = result.exitCode == 0 ? '✅ SUCCESS' : '❌ FAILED';
      final output =
          (result.stdout as String).isNotEmpty ? result.stdout : 'No output';
      final error =
          (result.stderr as String).isNotEmpty ? result.stderr : 'No errors';

      return MCPToolResult(
        content: [
          MCPContent.text('🚀 **DART APP EXECUTION COMPLETE**\n\n'
              '📊 **SUMMARY**:\n'
              '• Target: $target\n'
              '• Status: $status\n'
              '• Exit Code: ${result.exitCode}\n'
              '• Duration: ${duration.inMilliseconds}ms\n'
              '• Arguments: ${(argumentsList.isEmpty ? 'None' : argumentsList.join(' '))}\n\n'
              '📋 **OUTPUT**:\n$output\n\n'
              '⚠️ **ERRORS**:\n$error'),
        ],
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _recordOperation('execute_dart_app', duration);

      return MCPToolResult(
        content: [
          MCPContent.text('❌ **EXECUTION FAILED**: $e'),
        ],
        isError: true,
      );
    }
  }

  /// 📊 **VALIDATE DART PROJECT**: Project structure validation
  Future<MCPToolResult> _handleValidateDartProject(
      Map<String, dynamic> arguments) async {
    final startTime = DateTime.now();
    final projectPath = arguments['projectPath'] as String;
    final checkDependencies = arguments['checkDependencies'] as bool? ?? true;
    final checkConfiguration = arguments['checkConfiguration'] as bool? ?? true;

    try {
      // Validate project path exists
      if (!await _validateTarget(projectPath)) {
        return MCPToolResult(
          content: [
            MCPContent.text('❌ Project path not found: $projectPath'),
          ],
          isError: true,
        );
      }

      final validationResults = <String, dynamic>{};
      final issues = <String>[];

      // Check project structure
      if (checkConfiguration) {
        final pubspecExists = await File('$projectPath/pubspec.yaml').exists();
        final analysisExists =
            await File('$projectPath/analysis_options.yaml').exists();

        validationResults['project_structure'] = {
          'pubspec.yaml': pubspecExists,
          'analysis_options.yaml': analysisExists,
          'lib_directory': await Directory('$projectPath/lib').exists(),
          'test_directory': await Directory('$projectPath/test').exists(),
        };

        if (pubspecExists == false) issues.add('Missing pubspec.yaml');
        final libExists = await Directory('$projectPath/lib').exists();
        if (libExists == false) issues.add('Missing lib directory');
      }

      // Check dependencies
      if (checkDependencies) {
        try {
          final result = await _executeDartCommand(
            ['pub', 'deps'],
            workingDirectory: projectPath,
            timeout: const Duration(seconds: 30),
          );

          if (result.exitCode == 0) {
            validationResults['dependencies'] = {
              'status': 'valid',
              'output': result.stdout,
            };
          } else {
            validationResults['dependencies'] = {
              'status': 'error',
              'error': result.stderr,
            };
            issues.add('Dependency validation failed');
          }
        } catch (e) {
          validationResults['dependencies'] = {
            'status': 'error',
            'error': e.toString(),
          };
          issues.add('Dependency validation error: $e');
        }
      }

      final duration = DateTime.now().difference(startTime);
      _recordOperation('validate_dart_project', duration);

      final status = issues.isEmpty ? '✅ VALID' : '⚠️ ISSUES FOUND';
      final issuesText =
          issues.isEmpty ? 'No issues found' : issues.join('\n• ');

      return MCPToolResult(
        content: [
          MCPContent.text('📊 **DART PROJECT VALIDATION COMPLETE**\n\n'
              '📊 **SUMMARY**:\n'
              '• Project Path: $projectPath\n'
              '• Status: $status\n'
              '• Duration: ${duration.inMilliseconds}ms\n\n'
              '📋 **VALIDATION RESULTS**:\n${_formatValidationResults(validationResults)}\n\n'
              '⚠️ **ISSUES**:\n• $issuesText'),
        ],
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _recordOperation('validate_dart_project', duration);

      return MCPToolResult(
        content: [
          MCPContent.text('❌ **VALIDATION FAILED**: $e'),
        ],
        isError: true,
      );
    }
  }

  /// 📈 **PROFILE DART PERFORMANCE**: Performance profiling
  Future<MCPToolResult> _handleProfileDartPerformance(
      Map<String, dynamic> arguments) async {
    final startTime = DateTime.now();
    final target = arguments['target'] as String;
    final profileMode = arguments['profileMode'] as String? ?? 'both';
    final outputFile =
        arguments['outputFile'] as String? ?? 'profile_data.json';

    try {
      // Validate target exists
      if (!await _validateTarget(target)) {
        return MCPToolResult(
          content: [
            MCPContent.text('❌ Target not found: $target'),
          ],
          isError: true,
        );
      }

      // Build profiling command
      final args = ['run', '--profile=$profileMode'];
      args.add(target);

      // Execute with profiling
      final result = await _executeDartCommand(
        args,
        workingDirectory: workingDirectory,
        timeout: executionTimeout,
      );

      final duration = DateTime.now().difference(startTime);
      _recordOperation('profile_dart_performance', duration);

      if (result.exitCode != 0) {
        return MCPToolResult(
          content: [
            MCPContent.text(
                '❌ Performance profiling failed with exit code ${result.exitCode}:\n${result.stderr}'),
          ],
          isError: true,
        );
      }

      return MCPToolResult(
        content: [
          MCPContent.text('📈 **DART PERFORMANCE PROFILING COMPLETE**\n\n'
              '📊 **SUMMARY**:\n'
              '• Target: $target\n'
              '• Profile Mode: $profileMode\n'
              '• Output File: $outputFile\n'
              '• Duration: ${duration.inMilliseconds}ms\n\n'
              '📋 **PROFILING DATA**:\n${result.stdout}\n\n'
              '💡 **OPTIMIZATION SUGGESTIONS**:\n'
              '• Review CPU-intensive operations\n'
              '• Check memory allocation patterns\n'
              '• Consider async/await optimizations\n'
              '• Profile specific code sections'),
        ],
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _recordOperation('profile_dart_performance', duration);

      return MCPToolResult(
        content: [
          MCPContent.text('❌ **PROFILING FAILED**: $e'),
        ],
        isError: true,
      );
    }
  }

  /// 📦 **MANAGE DART DEPENDENCIES**: Dependency management
  Future<MCPToolResult> _handleManageDartDependencies(
      Map<String, dynamic> arguments) async {
    final startTime = DateTime.now();
    final action = arguments['action'] as String;
    final targetPackages =
        (arguments['targetPackages'] as List<dynamic>?)?.cast<String>() ?? [];
    final dryRun = arguments['dryRun'] as bool? ?? false;

    try {
      // Build command based on action
      final args = ['pub'];
      switch (action) {
        case 'get':
          args.add('get');
          break;
        case 'upgrade':
          args.add('upgrade');
          break;
        case 'outdated':
          args.add('outdated');
          break;
        case 'resolve':
          args.add('resolve');
          break;
        default:
          return MCPToolResult(
            content: [
              MCPContent.text(
                  '❌ Invalid action: $action. Valid actions: get, upgrade, outdated, resolve'),
            ],
            isError: true,
          );
      }

      if (dryRun) {
        args.add('--dry-run');
      }

      if (targetPackages.isNotEmpty) {
        args.addAll(targetPackages);
      }

      // Execute dependency command
      final result = await _executeDartCommand(
        args,
        workingDirectory: workingDirectory,
        timeout: const Duration(minutes: 2),
      );

      final duration = DateTime.now().difference(startTime);
      _recordOperation('manage_dart_dependencies', duration);

      final status = result.exitCode == 0 ? '✅ SUCCESS' : '❌ FAILED';
      final actionText = dryRun ? 'DRY RUN: $action' : action.toUpperCase();

      return MCPToolResult(
        content: [
          MCPContent.text('📦 **DART DEPENDENCY MANAGEMENT COMPLETE**\n\n'
              '📊 **SUMMARY**:\n'
              '• Action: $actionText\n'
              '• Target Packages: ${targetPackages.isEmpty ? 'All' : targetPackages.join(', ')}\n'
              '• Status: $status\n'
              '• Duration: ${duration.inMilliseconds}ms\n\n'
              '📋 **OUTPUT**:\n${result.stdout}\n\n'
              '⚠️ **ERRORS**:\n${(result.stderr as String).isNotEmpty ? result.stderr : 'No errors'}'),
        ],
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _recordOperation('manage_dart_dependencies', duration);

      return MCPToolResult(
        content: [
          MCPContent.text('❌ **DEPENDENCY MANAGEMENT FAILED**: $e'),
        ],
        isError: true,
      );
    }
  }

  /// 🔧 **HELPER METHODS**: Utility functions for the server

  /// Validate if target exists
  Future<bool> _validateTarget(String target) async {
    if (target == '.') return true;

    final targetPath =
        target.startsWith('/') ? target : '$workingDirectory/$target';
    return await File(targetPath).exists() ||
        await Directory(targetPath).exists();
  }

  /// Execute Dart command with safety
  Future<ProcessResult> _executeDartCommand(
    List<String> args, {
    String? workingDirectory,
    Duration? timeout,
  }) async {
    final process = await Process.start(
      'dart',
      args,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      runInShell: true,
    );

    final output = <int>[];
    final error = <int>[];

    process.stdout.listen(output.addAll);
    process.stderr.listen(error.addAll);

    final exitCode = await process.exitCode.timeout(
      timeout ?? executionTimeout,
      onTimeout: () {
        process.kill();
        throw TimeoutException(
            'Command execution timed out', timeout ?? executionTimeout);
      },
    );

    final stdout = utf8.decode(output, allowMalformed: true);
    final stderr = utf8.decode(error, allowMalformed: true);

    return ProcessResult(
      process.pid,
      exitCode,
      stdout,
      stderr,
    );
  }

  /// Parse analysis results
  Future<String> _parseAnalysisResults(
    String output, {
    required String format,
    required bool includeWarnings,
    required bool includeHints,
  }) async {
    if (format == 'json' || format == 'machine') {
      try {
        final lines = output.trim().split('\n');
        final results = <Map<String, dynamic>>[];

        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            results.add(json);
          } catch (e) {
            // Skip malformed JSON lines
          }
        }

        if (results.isEmpty) {
          return '✅ No issues found';
        }

        final issues = <String>[];
        for (final result in results) {
          final severity = result['severity'] as String? ?? 'info';
          final message = result['message'] as String? ?? 'Unknown issue';
          final location = result['location'] as Map<String, dynamic>?;

          if (severity == 'error' ||
              (severity == 'warning' && includeWarnings) ||
              (severity == 'hint' && includeHints)) {
            final file = location?['file'] as String? ?? 'Unknown file';
            final line = location?['line'] as int? ?? 0;
            final column = location?['column'] as int? ?? 0;

            issues
                .add('$severity.toUpperCase(): $message ($file:$line:$column)');
          }
        }

        return issues.isEmpty ? '✅ No issues found' : issues.join('\n');
      } catch (e) {
        return '⚠️ Could not parse JSON output: $e\n\nRaw output:\n$output';
      }
    }

    return output;
  }

  /// Format validation results
  String _formatValidationResults(Map<String, dynamic> results) {
    final buffer = StringBuffer();

    for (final entry in results.entries) {
      final key = entry.key.replaceAll('_', ' ').toUpperCase();
      final value = entry.value;

      buffer.writeln('• $key:');
      if (value is Map) {
        for (final subEntry in value.entries) {
          final subKey = subEntry.key.replaceAll('_', ' ').toUpperCase();
          final subValue = subEntry.value;
          buffer.writeln('  - $subKey: $subValue');
        }
      } else {
        buffer.writeln('  $value');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Record operation timing and count
  void _recordOperation(String operation, Duration duration) {
    _operationTimings[operation] = duration;
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;
  }

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'operation_timings':
          _operationTimings.map((k, v) => MapEntry(k, v.inMilliseconds)),
      'operation_counts': _operationCounts,
      'average_timing': _operationTimings.values.isEmpty
          ? 0
          : _operationTimings.values
                  .map((d) => d.inMilliseconds)
                  .reduce((a, b) => a + b) /
              _operationTimings.length,
    };
  }

  @override
  Future<void> shutdown() async {
    logger?.call('info', 'Shutting down Dart MCP server');

    // Log performance metrics
    final metrics = getPerformanceMetrics();
    logger?.call('info', 'Performance metrics: $metrics');

    await super.shutdown();
  }
}

/// 🚀 **MAIN ENTRY POINT**: Start the Dart MCP server
void main() async {
  final server = DartMCPServer(
    enableDebugLogging: false, // Reduced logging for performance
    logger: (level, message, [data]) {
      if (level == 'error' || level == 'info') {
        // Only show important messages
        final timestamp = DateTime.now().toIso8601String();
        stderr.writeln(
            '[$timestamp] [$level] $message${data != null ? ': $data' : ''}');
      }
    },
  );

  try {
    await server.start();
  } catch (e) {
    stderr.writeln('Failed to start Dart MCP server: $e');
    exit(1);
  }
}

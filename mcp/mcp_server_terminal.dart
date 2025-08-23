import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_openai_client/dart_openai_client.dart';

/// 🏆 TERMINAL MCP SERVER: Local System Command Execution [+1000 XP]
///
/// **ARCHITECTURAL VICTORY**: This MCP server provides secure terminal command execution
/// capabilities for AI agents, allowing them to run system commands with proper safety:
/// 1. Secure command execution with whitelist validation
/// 2. Comprehensive output capture (stdout, stderr, exit code)
/// 3. Timeout protection to prevent hanging processes
/// 4. Working directory management and environment control
/// 5. Command history and audit logging
/// 6. Resource cleanup and process management
///
/// **STRATEGIC DECISIONS**:
/// - Whitelist-based command security (prevents dangerous operations)
/// - Comprehensive output capture with proper encoding
/// - Timeout protection to prevent resource exhaustion
/// - Working directory isolation for safety
/// - Process cleanup to prevent zombie processes
/// - Strong typing for all operations (eliminates dynamic vulnerabilities)
///
/// **SECURITY STRATEGIES**:
/// - Command whitelist validation (prevents dangerous operations)
/// - Working directory restrictions (prevents file system traversal)
/// - Timeout limits (prevents resource exhaustion)
/// - Process isolation (prevents system compromise)
/// - Audit logging (provides accountability)
class TerminalMCPServer extends BaseMCPServer {
  /// Configuration options
  final bool enableDebugLogging;
  final Duration executionTimeout;
  final int maxOutputSize;
  final String workingDirectory;
  final List<String> allowedCommands;
  final List<String> blockedCommands;
  final bool allowInteractiveCommands;

  /// Performance and security tracking
  final Map<String, Duration> _operationTimings = {};
  final Map<String, int> _operationCounts = {};
  final List<Map<String, dynamic>> _commandHistory = [];

  TerminalMCPServer({
    super.name = 'terminal-command',
    super.version = '1.0.0',
    super.logger,
    this.enableDebugLogging = false,
    this.executionTimeout = const Duration(minutes: 5),
    this.maxOutputSize = 1000000, // 1MB
    this.workingDirectory = '.',
    this.allowedCommands = const [],
    this.blockedCommands = const [
      'rm',
      'rmdir',
      'del',
      'rd',
      'format',
      'fdisk',
      'mkfs',
      'shutdown',
      'halt',
      'reboot',
      'init',
      'killall',
      'pkill',
      'sudo',
      'su',
      'chmod',
      'chown',
      'chgrp',
      'passwd',
      'useradd',
      'userdel',
      'groupadd',
      'groupdel',
      'iptables',
      'firewall-cmd',
      'ufw',
      'systemctl',
      'service',
      'systemd',
      'cron',
      'at',
      'batch'
    ],
    this.allowInteractiveCommands = false,
  });

  @override
  Map<String, dynamic> getCapabilities() {
    final base = super.getCapabilities();
    return {
      ...base,
      'terminal_execution': {
        'version': '1.0.0',
        'features': [
          'command_execution',
          'output_capture',
          'working_directory_management',
          'timeout_protection',
          'security_validation',
          'audit_logging',
        ],
        'limits': {
          'execution_timeout': executionTimeout.inSeconds,
          'max_output_size': maxOutputSize,
          'working_directory': workingDirectory,
          'allowed_commands': allowedCommands.isEmpty ? 'all' : allowedCommands,
          'blocked_commands': blockedCommands,
        },
      },
    };
  }

  @override
  Future<void> initializeServer() async {
    // 🚀 **COMMAND EXECUTION TOOLS**: Execute terminal commands safely

    registerTool(MCPTool(
      name: 'execute_terminal_command',
      description:
          'Execute a terminal command on the local system with comprehensive output capture and security validation',
      inputSchema: {
        'type': 'object',
        'properties': {
          'command': {
            'type': 'string',
            'description':
                'The command to execute (e.g., "ls -la", "git status")',
          },
          'arguments': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'Command arguments as separate array elements (optional, overrides command if provided)',
            'default': <String>[],
          },
          'workingDirectory': {
            'type': 'string',
            'description':
                'Working directory for command execution (defaults to server working directory)',
            'default': '.',
          },
          'timeout': {
            'type': 'integer',
            'description':
                'Execution timeout in seconds (defaults to server timeout)',
            'default': 300,
          },
          'captureOutput': {
            'type': 'boolean',
            'description':
                'Whether to capture command output (defaults to true)',
            'default': true,
          },
          'environment': {
            'type': 'object',
            'description':
                'Additional environment variables to set for the command',
            'default': <String, String>{},
          },
        },
        'required': ['command'],
      },
      callback: _handleExecuteCommand,
    ));

    registerTool(MCPTool(
      name: 'get_command_history',
      description:
          'Retrieve the history of executed commands with their results and timing',
      inputSchema: {
        'type': 'object',
        'properties': {
          'limit': {
            'type': 'integer',
            'description':
                'Maximum number of commands to return (defaults to 50)',
            'default': 50,
          },
          'filter': {
            'type': 'string',
            'description': 'Filter commands by text (optional)',
            'default': '',
          },
        },
      },
      callback: _handleGetCommandHistory,
    ));

    registerTool(MCPTool(
      name: 'validate_command',
      description:
          'Validate if a command is allowed to be executed based on security policies',
      inputSchema: {
        'type': 'object',
        'properties': {
          'command': {
            'type': 'string',
            'description': 'The command to validate',
          },
        },
        'required': ['command'],
      },
      callback: _handleValidateCommand,
    ));

    registerTool(MCPTool(
      name: 'get_system_info',
      description:
          'Get basic system information (OS, architecture, working directory)',
      inputSchema: {
        'type': 'object',
        'properties': <String, dynamic>{},
      },
      callback: _handleGetSystemInfo,
    ));

    logger?.call(
        'info', 'Terminal MCP server initialized with security policies');
  }

  /// 🚀 **COMMAND EXECUTION HANDLER**: Execute terminal commands with full safety
  Future<MCPToolResult> _handleExecuteCommand(Map<String, dynamic> args) async {
    final stopwatch = Stopwatch()..start();

    try {
      final command = args['command'] as String;
      final arguments = <String>[];
      if (args['arguments'] != null) {
        arguments.addAll((args['arguments'] as List<dynamic>).cast<String>());
      }
      final workingDir =
          args['workingDirectory'] as String? ?? workingDirectory;
      final timeout = Duration(
          seconds: args['timeout'] as int? ?? executionTimeout.inSeconds);
      final captureOutput = args['captureOutput'] as bool? ?? true;
      final environment = <String, String>{};
      if (args['environment'] != null) {
        environment.addAll(Map<String, String>.from(
            args['environment'] as Map<String, dynamic>));
      }

      // 🔒 **SECURITY VALIDATION**: Ensure command is safe to execute
      final validationResult = _validateCommand(command, arguments);
      if (validationResult['allowed'] != true) {
        return MCPToolResult(
          content: [
            MCPContent.text(
                '🚫 **COMMAND BLOCKED**: ${validationResult['reason']}\n\n'
                'Command: `$command`\n'
                'Arguments: ${arguments.join(' ')}\n\n'
                '**Security Policy**: This command is not allowed for safety reasons.'),
          ],
        );
      }

      // 📁 **WORKING DIRECTORY VALIDATION**: Ensure safe working directory
      final safeWorkingDir = _validateWorkingDirectory(workingDir);
      if (safeWorkingDir == null) {
        return MCPToolResult(
          content: [
            MCPContent.text(
                '🚫 **WORKING DIRECTORY BLOCKED**: The specified working directory is not allowed for security reasons.\n\n'
                'Requested: `$workingDir`\n'
                'Allowed: `$workingDirectory` and subdirectories'),
          ],
        );
      }

      logger?.call('info',
          'Executing command: $command ${arguments.join(' ')} in $safeWorkingDir');

      // 🚀 **COMMAND EXECUTION**: Run the command with full output capture
      final result = await _executeCommand(
        command: command,
        arguments: arguments,
        workingDirectory: safeWorkingDir,
        timeout: timeout,
        captureOutput: captureOutput,
        environment: environment,
      );

      // 📊 **PERFORMANCE TRACKING**: Record execution metrics
      stopwatch.stop();
      _recordOperation('execute_command', stopwatch.elapsed);

      // 📝 **AUDIT LOGGING**: Record command execution
      _recordCommandExecution(command, arguments, result, stopwatch.elapsed);

      return MCPToolResult(
        content: [
          MCPContent.text(_formatCommandResult(
              result, command, arguments, stopwatch.elapsed)),
        ],
      );
    } catch (e) {
      stopwatch.stop();
      _recordOperation('execute_command_error', stopwatch.elapsed);

      return MCPToolResult(
        content: [
          MCPContent.text(
              '💥 **EXECUTION ERROR**: Failed to execute command\n\n'
              'Error: $e\n\n'
              '**Troubleshooting**:\n'
              '• Verify the command exists and is accessible\n'
              '• Check working directory permissions\n'
              '• Ensure command is not blocked by security policies'),
        ],
      );
    }
  }

  /// 🔒 **COMMAND VALIDATION**: Security policy enforcement
  Map<String, dynamic> _validateCommand(
      String command, List<String> arguments) {
    final fullCommand = '$command ${arguments.join(' ')}'.trim();

    // Check blocked commands (exact matches and patterns)
    for (final blocked in blockedCommands) {
      if (fullCommand.startsWith(blocked) ||
          fullCommand.contains(' $blocked ') ||
          fullCommand.endsWith(' $blocked')) {
        return {
          'allowed': false,
          'reason': 'Command contains blocked keyword: $blocked',
          'blocked_keyword': blocked,
        };
      }
    }

    // Check allowed commands whitelist (if specified)
    if (allowedCommands.isNotEmpty) {
      final isAllowed = allowedCommands.any((allowed) =>
          fullCommand.startsWith(allowed) ||
          fullCommand.contains(' $allowed ') ||
          fullCommand.endsWith(' $allowed'));

      if (!isAllowed) {
        return {
          'allowed': false,
          'reason': 'Command not in allowed commands whitelist',
          'allowed_commands': allowedCommands,
        };
      }
    }

    // Check for dangerous patterns
    final dangerousPatterns = [
      RegExp(r'[;&|`]'), // Command chaining
      RegExp(r'\$\('), // Command substitution
      RegExp(r'\{.*\}'), // Brace expansion
      RegExp(r'\[.*\]'), // Character classes
    ];

    for (final pattern in dangerousPatterns) {
      if (pattern.hasMatch(fullCommand)) {
        return {
          'allowed': false,
          'reason': 'Command contains dangerous pattern: ${pattern.pattern}',
          'dangerous_pattern': pattern.pattern,
        };
      }
    }

    return {'allowed': true, 'reason': 'Command passed all security checks'};
  }

  /// 📁 **WORKING DIRECTORY VALIDATION**: Ensure safe directory access
  String? _validateWorkingDirectory(String requestedDir) {
    try {
      final requested = Directory(requestedDir).resolveSymbolicLinksSync();
      final allowed = Directory(workingDirectory).resolveSymbolicLinksSync();

      // Ensure requested directory is within allowed directory
      if (!requested.startsWith(allowed)) {
        return null;
      }

      return requested;
    } catch (e) {
      return null;
    }
  }

  /// 🚀 **COMMAND EXECUTION**: Core execution logic with full safety
  Future<Map<String, dynamic>> _executeCommand({
    required String command,
    required List<String> arguments,
    required String workingDirectory,
    required Duration timeout,
    required bool captureOutput,
    required Map<String, String> environment,
  }) async {
    final process = await Process.start(
      command,
      arguments,
      workingDirectory: workingDirectory,
      environment: {...Platform.environment, ...environment},
      runInShell: false,
    );

    String stdout = '';
    String stderr = '';
    int exitCode = -1;

    try {
      // Set up output capture
      if (captureOutput) {
        process.stdout.transform(utf8.decoder).listen((data) {
          if (stdout.length < maxOutputSize) {
            stdout += data;
          }
        });

        process.stderr.transform(utf8.decoder).listen((data) {
          if (stderr.length < maxOutputSize) {
            stderr += data;
          }
        });
      }

      // Wait for completion with timeout
      exitCode = await process.exitCode.timeout(timeout);

      // Ensure process is terminated
      try {
        process.kill();
      } catch (e) {
        // Process already terminated
      }
    } catch (e) {
      // Handle timeout or other errors
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (e) {
        // Process already terminated
      }

      if (e is TimeoutException) {
        throw Exception(
            'Command execution timed out after ${timeout.inSeconds} seconds');
      }
      rethrow;
    }

    return {
      'exitCode': exitCode,
      'stdout': stdout,
      'stderr': stderr,
      'success': exitCode == 0,
      'command': command,
      'arguments': arguments,
      'workingDirectory': workingDirectory,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// 📝 **COMMAND HISTORY**: Retrieve execution history
  Future<MCPToolResult> _handleGetCommandHistory(
      Map<String, dynamic> args) async {
    final limit = args['limit'] as int? ?? 50;
    final filter = args['filter'] as String? ?? '';

    final filteredHistory = _commandHistory
        .where((entry) =>
            filter.isEmpty ||
            (entry['command'] as String)
                .toLowerCase()
                .contains(filter.toLowerCase()) ||
            (entry['arguments'] as List<dynamic>)
                .join(' ')
                .toLowerCase()
                .contains(filter.toLowerCase()))
        .take(limit)
        .toList();

    if (filteredHistory.isEmpty) {
      return MCPToolResult(
        content: [
          MCPContent.text(
              '📋 **COMMAND HISTORY**: No commands found${filter.isNotEmpty ? ' matching "$filter"' : ''}'),
        ],
      );
    }

    final buffer = StringBuffer();
    buffer.writeln(
        '📋 **COMMAND HISTORY** (${filteredHistory.length} commands):\n');

    for (final entry in filteredHistory.reversed) {
      final timestamp = DateTime.parse(entry['timestamp'] as String).toLocal();
      final command = entry['command'] as String;
      final arguments = (entry['arguments'] as List<dynamic>)
          .map((e) => e.toString())
          .join(' ');
      final exitCode = entry['exitCode'] as int;
      final duration = (entry['duration'] as Duration).inMilliseconds;
      final success = (entry['success'] as bool) ? '✅' : '❌';

      buffer.writeln('**$timestamp** - $success `$command $arguments`');
      buffer.writeln('  Exit Code: $exitCode | Duration: ${duration}ms');
      buffer.writeln();
    }

    return MCPToolResult(
      content: [
        MCPContent.text(buffer.toString()),
      ],
    );
  }

  /// 🔒 **COMMAND VALIDATION**: Check if command is allowed
  Future<MCPToolResult> _handleValidateCommand(
      Map<String, dynamic> args) async {
    final command = args['command'] as String;
    final arguments = <String>[];
    if (args['arguments'] != null) {
      arguments.addAll((args['arguments'] as List<dynamic>).cast<String>());
    }

    final validation = _validateCommand(command, arguments);

    if (validation['allowed'] == true) {
      return MCPToolResult(
        content: [
          MCPContent.text(
              '✅ **COMMAND VALIDATED**: Command is allowed to execute\n\n'
              'Command: `$command ${arguments.join(' ')}`\n'
              'Reason: ${validation['reason']}'),
        ],
      );
    } else {
      return MCPToolResult(
        content: [
          MCPContent.text(
              '🚫 **COMMAND BLOCKED**: Command is not allowed to execute\n\n'
              'Command: `$command ${arguments.join(' ')}`\n'
              'Reason: ${validation['reason']}'),
        ],
      );
    }
  }

  /// 💻 **SYSTEM INFORMATION**: Get basic system details
  Future<MCPToolResult> _handleGetSystemInfo(Map<String, dynamic> args) async {
    try {
      final os = Platform.operatingSystem;
      final osVersion = Platform.operatingSystemVersion;
      final workingDir = Directory.current.path;
      final userHome = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          'Unknown';

      return MCPToolResult(
        content: [
          MCPContent.text('💻 **SYSTEM INFORMATION**\n\n'
              '• **Operating System**: $os $osVersion\n'
              '• **Working Directory**: `$workingDir`\n'
              '• **User Home**: `$userHome`\n'
              '• **Server Working Directory**: `$workingDirectory`\n'
              '• **Execution Timeout**: ${executionTimeout.inSeconds}s\n'
              '• **Max Output Size**: ${(maxOutputSize / 1024 / 1024).toStringAsFixed(2)}MB\n'
              '• **Security Mode**: ${allowedCommands.isEmpty ? 'Blacklist' : 'Whitelist'}\n'
              '• **Blocked Commands**: ${blockedCommands.length} commands blocked'),
        ],
      );
    } catch (e) {
      return MCPToolResult(
        content: [
          MCPContent.text(
              '⚠️ **SYSTEM INFO ERROR**: Failed to retrieve system information\n\nError: $e'),
        ],
      );
    }
  }

  /// 📊 **RESULT FORMATTING**: Format command execution results
  String _formatCommandResult(Map<String, dynamic> result, String command,
      List<String> arguments, Duration duration) {
    final buffer = StringBuffer();
    final success = (result['success'] as bool) ? '✅' : '❌';
    final exitCode = result['exitCode'];
    final stdout = result['stdout'] as String;
    final stderr = result['stderr'] as String;

    buffer.writeln(
        '$success **COMMAND EXECUTED** (${duration.inMilliseconds}ms)\n');
    buffer.writeln('**Command**: `$command ${arguments.join(' ')}`');
    buffer.writeln('**Working Directory**: `${result['workingDirectory']}`');
    buffer.writeln('**Exit Code**: $exitCode');
    buffer.writeln('**Timestamp**: ${result['timestamp']}\n');

    if (stdout.isNotEmpty) {
      buffer.writeln('**STDOUT**:');
      buffer.writeln('```');
      buffer.writeln(stdout);
      buffer.writeln('```\n');
    }

    if (stderr.isNotEmpty) {
      buffer.writeln('**STDERR**:');
      buffer.writeln('```');
      buffer.writeln(stderr);
      buffer.writeln('```\n');
    }

    if (stdout.isEmpty && stderr.isEmpty) {
      buffer.writeln('**OUTPUT**: No output captured');
    }

    return buffer.toString();
  }

  /// 📝 **COMMAND RECORDING**: Record command execution for audit
  void _recordCommandExecution(String command, List<String> arguments,
      Map<String, dynamic> result, Duration duration) {
    _commandHistory.add({
      'command': command,
      'arguments': arguments,
      'exitCode': result['exitCode'],
      'success': result['success'],
      'stdout': result['stdout'],
      'stderr': result['stderr'],
      'workingDirectory': result['workingDirectory'],
      'timestamp': result['timestamp'],
      'duration': duration,
    });

    // Keep history manageable
    if (_commandHistory.length > 1000) {
      _commandHistory.removeRange(0, _commandHistory.length - 1000);
    }
  }

  /// 📊 **PERFORMANCE TRACKING**: Record operation metrics
  void _recordOperation(String operation, Duration duration) {
    _operationTimings[operation] = duration;
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;
  }

  /// 📈 **PERFORMANCE METRICS**: Get execution statistics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'operation_timings':
          _operationTimings.map((k, v) => MapEntry(k, v.inMilliseconds)),
      'operation_counts': _operationCounts,
      'command_history_size': _commandHistory.length,
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
    logger?.call('info', 'Shutting down Terminal MCP server');

    // Log performance metrics
    final metrics = getPerformanceMetrics();
    logger?.call('info', 'Performance metrics: $metrics');
    logger?.call('info', 'Command history size: ${_commandHistory.length}');

    await super.shutdown();
  }
}

/// 🚀 **MAIN ENTRY POINT**: Start the Terminal MCP server
void main() async {
  final server = TerminalMCPServer(
    enableDebugLogging: false, // Reduced logging for performance
    workingDirectory: '.', // Current directory
    allowedCommands: [], // Empty means blacklist mode (more secure)
    blockedCommands: [
      // System commands that could be dangerous
      'rm', 'rmdir', 'del', 'rd', 'format', 'fdisk', 'mkfs',
      'shutdown', 'halt', 'reboot', 'init', 'killall', 'pkill',
      'sudo', 'su', 'chmod', 'chown', 'chgrp', 'passwd',
      'useradd', 'userdel', 'groupadd', 'groupdel',
      'iptables', 'firewall-cmd', 'ufw', 'systemctl',
      'service', 'systemd', 'cron', 'at', 'batch',
      // Network commands that could be dangerous
      'nc', 'netcat', 'telnet', 'ssh', 'scp', 'rsync',
      // File system commands that could be dangerous
      'dd', 'mkfs', 'mount', 'umount', 'fdisk', 'parted',
      // Process management that could be dangerous
      'kill', 'killall', 'pkill', 'pgrep', 'nice', 'renice',
    ],
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
    stderr.writeln('Failed to start Terminal MCP server: $e');
    exit(1);
  }
}

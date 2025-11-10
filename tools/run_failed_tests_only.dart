import 'dart:async';
import 'dart:convert';
import 'dart:io';

class FailureDetails {
  FailureDetails(this.name);

  final String name;
  String result = 'error';
  final List<String> errors = <String>[];
  final List<String> prints = <String>[];
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

Future<int> main(List<String> args) async {
  final command = <String>['dart', 'test', '--reporter', 'json', ...args];
  final process = await Process.start(
    command.first,
    command.sublist(1),
    runInShell: false,
  );

  final testNames = <int, String>{};
  final outputs = <int, List<String>>{};
  final failures = <int, FailureDetails>{};
  final stderrBuffer = StringBuffer();

  Future<void> handleStdout() async {
    final lines =
        process.stdout.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      late final Map<String, dynamic> event;
      try {
        event = jsonDecode(line) as Map<String, dynamic>;
      } on FormatException {
        stdout.writeln(line);
        continue;
      }

      final eventType = event['type'] as String?;
      final testId = _asInt(event['testID']);

      if (eventType == 'testStart') {
        final test = event['test'];
        if (test is Map<String, dynamic>) {
          final id = _asInt(test['id']);
          final name = test['name'] as String? ?? '<unnamed test>';
          if (id != null) {
            testNames[id] = name;
          }
        }
        continue;
      }

      if (eventType == 'print' && testId != null) {
        final message = event['message'] as String?;
        if (message != null) {
          outputs.putIfAbsent(testId, () => <String>[]).add(message);
        }
        continue;
      }

      if (eventType == 'error' && testId != null) {
        final failure = failures.putIfAbsent(
          testId,
          () => FailureDetails(testNames[testId] ?? '<unnamed test>'),
        );
        final error = event['error'] as String?;
        if (error != null) {
          failure.errors.add(error.trim());
        }
        final stack = event['stackTrace'] as String?;
        if (stack != null && stack.trim().isNotEmpty) {
          failure.errors.add(stack.trim());
        }
        continue;
      }

      if (eventType == 'testDone' && testId != null) {
        final result = event['result'] as String?;
        if (result != 'success') {
          final failure = failures.putIfAbsent(
            testId,
            () => FailureDetails(testNames[testId] ?? '<unnamed test>'),
          );
          failure.result = result ?? 'error';
          final buffered = outputs.remove(testId);
          if (buffered != null) {
            failure.prints.addAll(buffered);
          }
        } else {
          outputs.remove(testId);
          failures.remove(testId);
        }
      }
    }
  }

  Future<void> handleStderr() async {
    await for (final chunk in process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      stderrBuffer.writeln(chunk);
    }
  }

  await Future.wait(
      [handleStdout(), handleStderr(), process.exitCode.then((_) {})]);

  final exitCode = await process.exitCode;

  if (stderrBuffer.isNotEmpty) {
    stderr.write(stderrBuffer.toString());
  }

  if (failures.isEmpty) {
    stdout.writeln('✅ All tests passed — no failures to show.');
    return exitCode;
  }

  stdout.writeln('❌ Failing tests summary:\n');
  var index = 1;
  for (final failure in failures.values) {
    stdout.writeln('${index++}. ${failure.name} [${failure.result}]');
    for (final message in failure.prints) {
      if (message.trim().isEmpty) {
        continue;
      }
      stdout.writeln('   • output: ${message.trim()}');
    }
    for (final error in failure.errors) {
      stdout.writeln(
          '   • error: ${error.replaceAll(RegExp(r"\s+"), ' ').trim()}');
    }
    stdout.writeln();
  }

  return exitCode == 0 ? 1 : exitCode;
}

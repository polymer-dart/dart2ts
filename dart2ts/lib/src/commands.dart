import 'dart:async';
import 'package:args/command_runner.dart';
import 'package:dart2ts/src/deps_installer.dart' show Dart2TsInstallCommand;
import 'package:logging/logging.dart';
import 'package:dart2ts/src/code_generator2.dart' show Dart2TsBuildCommand;

Logger _logger = new Logger('dart2ts.lib.command');

class Dart2TsCommandRunner extends CommandRunner<bool> {
  Dart2TsCommandRunner() : super('dart2ts', 'a better interface to TS') {
    addCommand(new Dart2TsBuildCommand());
    addCommand(new Dart2TsInstallCommand());
  }
}

const String BOLD = '\x1b[1m';
const String DIM = '\x1b[2m';
const String UNDERLINED = '\x1b[4m';
const String BLINK = '\x1b[5m';
const String REVERSE = '\x1b[7m';
const String NORMAL = '\x1b[0m';

Future main(List<String> args) {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${DIM}[${record.time}]${NORMAL} '
        '${BOLD}${record.level}${NORMAL} '
        '${record.loggerName}, ${record.message}');
    if (record.error != null) {
      print("ERROR:\n${BLINK}${record.error}${NORMAL}");
      print("STACKTRACE:\n${record.stackTrace??''}");
    }
  });
  return new Dart2TsCommandRunner().run(args);
}